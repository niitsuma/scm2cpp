#lang racket
;;;; The array-algebra derivation as a translator pass (--derive).
;;;;
;;;; rewrite-driver.scm derives the covariance form of a coordinate
;;;; descent -- raise the loops to the algebra, difference the memoised
;;;; context, merge and lower the tables -- from a statement list, given
;;;; which vector is the scratch (the residual) and which holds the
;;;; coefficients, and given the shapes of the arrays.  This module is
;;;; the glue that finds those in a source file so the translator can
;;;; run the derivation without being told:
;;;;
;;;;   shapes      a (with-arrays DECLS BODY ...) in a function body
;;;;               declares them; rank two and up are dims, rank one
;;;;               are extents.  A function without one is left alone:
;;;;               nothing in a flat vector-ref tells the raiser that
;;;;               x[j*n+i] is a row of a p-by-n matrix.
;;;;   scratch     the vector an update site decrements by a scaled
;;;;               row -- (array-dec! V (scale D (row X J))) once the
;;;;               loops are raised -- and the coefficients the vector
;;;;               written at the same coordinate J.  Each candidate
;;;;               pair is offered; the first the driver differences is
;;;;               kept.
;;;;   liveness    the caller says which parameters are outputs; a
;;;;               scratch that is one is restored at the end, and a
;;;;               fill nothing outside reads is dead.
;;;;
;;;; The pass runs on the source as written, before macro expansion,
;;;; because that is where with-arrays still stands: the derived body
;;;; goes back under the same declaration, and the tables the driver
;;;; introduces carry their own nested with-arrays, so the ordinary
;;;; expansion that follows lowers both.  A function whose loops are
;;;; named lets rather than do forms is not raised; the pre-pass that
;;;; turns those into loops runs after expansion, past this point.

(require (only-in (file "rewrite-driver.scm") derive-fixpoint/log)
         (only-in (file "rewrite-raise.scm") raise-loops)
         (only-in (file "rewrite-incremental.scm") walk-collect))

(provide derive-enabled? derive-forms derive-log)

(define (derive-enabled?)
  (equal? (getenv "SCM2CPP_DERIVE") "1"))

;; What fired, per function, on the last derive-forms call: an alist
;; (fname . log) for the report on stderr and for tests.
(define derive-log (make-parameter '()))

;; ---- shapes from with-arrays ----

(define (decl-dims decls)
  (for/list ([d decls] #:when (>= (length (cadr d)) 2))
    (list (car d) (cadr d))))

(define (decl-extents decls)
  (for/list ([d decls] #:when (= (length (cadr d)) 1))
    (cons (car d) (car (cadr d)))))

;; ---- the scratch and the coefficients, read off the raised sweep ----

;; Candidate (v . beta) pairs, in order of appearance.  V is the target
;; of a whole-vector or row decrement by a scaled row of some declared
;; matrix; BETA is any vector written at the update's coordinate.
(define (scratch-candidates raised)
  (define updates
    (filter values
            (for/list ([e (walk-collect pair? raised)])
              (match e
                [`(array-dec! ,(? symbol? v) (scale ,_ (row ,_ ,(? symbol? j))))
                 (cons v j)]
                [`(row-dec! ,(? symbol? v) ,_ (scale ,_ (row ,_ ,(? symbol? j))))
                 (cons v j)]
                [_ #f]))))
  (remove-duplicates
   (for*/list ([u updates]
               [e (walk-collect pair? raised)]
               #:when (match e
                        [`(,(or 'vector-set! 'array-set!) ,(? symbol? b) ,(== (cdr u)) ,_)
                         (not (eq? b (car u)))]
                        ;; the matrix coefficients of a row update
                        [`(array-set! ,(? symbol? b) ,(== (cdr u)) ,_ ,_)
                         (not (eq? b (car u)))]
                        [_ #f]))
     (cons (car u) (cadr e)))))

;; ---- one function ----

;; The first with-arrays in statement position of BODY, as
;; (values decls wbody rebuild) where (rebuild new-wbody) is BODY with
;; that form's body replaced; or #f when there is none.
(define (find-with-arrays body)
  (let loop ([pre '()] [rest body])
    (cond
      [(null? rest) (values #f #f #f)]
      [(match (car rest) [`(with-arrays ,(? list?) ,_ ...) #t] [_ #f])
       (match-define `(with-arrays ,decls ,wbody ...) (car rest))
       (values decls wbody
               (lambda (new)
                 (append (reverse pre)
                         (list `(with-arrays ,decls ,@new))
                         (cdr rest))))]
      [else (loop (cons (car rest) pre) (cdr rest))])))

;; (* p) for a rank-one table's cell count is what the driver writes;
;; the emitter wants the plain operand.
(define (tidy e)
  (match e
    [`(* ,x) (tidy x)]
    [(? pair?) (map tidy e)]
    [_ e]))

;; ---- the matrix level ----
;;
;; The differencing writes its products cell by cell, in the algebra
;; one rank below the one they have:
;;   (range-for (k1 P) (range-for (k2 P)
;;     (array-set! G k1 k2 (array-sum (* (row X k1) (row X k2))))))
;;   (range-for (k P) (array-set! C k (array-sum (* (row X k) V))))
;;   (range-for (j P) (array-dec! R (scale E(j) (row X j))))
;; These are G = X X^T, C = X V and R -= X^T D, and the one thing that
;; says so is that the loop index appears only as a row selector or an
;; element index.  Folding them to (matmul ...) is what lets --blas
;; hand each to one BLAS call; the algebra is unchanged, only spelled
;; at its rank.  The coefficient vector D of the third is E with the
;; index taken out -- (vector-ref V j) is V -- so it may name a vector
;; the scope did not declare (the saved coefficients, say); those get
;; a declaration on the nested with-arrays whose body they stand in.
;; Returns the folded body and whether anything folded.
(define (fold-matmul e outer-decls)
  (define fired #f)
  (define outer-names (map car outer-decls))
  (define (mat? x dims) (and (symbol? x) (assq x dims)))
  (define (mentions? k e)
    (cond [(eq? e k) #t] [(pair? e) (or (mentions? k (car e)) (mentions? k (cdr e)))] [else #f]))
  ;; E with the indices KS removed, as a vector (one index) or matrix
  ;; (two) expression, or #f; the arrays it indexed are collected in
  ;; USED
  (define (deindex e ks used)
    (match e
      [`(,(or 'vector-ref 'array-ref) ,(? symbol? v) ,is ...)
       #:when (equal? is ks)
       (set-box! used (cons v (unbox used))) v]
      [(? number?) e]
      [(? symbol?) (and (not (memq e ks)) e)]
      [`(,(and op (or '+ '- '*)) ,args ...)
       (let ([ds (map (lambda (a) (deindex a ks used)) args)])
         (and (andmap values ds) `(,op ,@ds)))]
      [_ #f]))
  (define (walk e dims extra)
    (match e
      [`(with-arrays ,decls ,body ...)
       (let* ([inner (append (for/list ([d decls] #:when (>= (length (cadr d)) 2))
                               (list (car d) (cadr d)))
                             dims)]
              [ext (box '())]
              [body2 (map (lambda (b) (walk b inner ext)) body)]
              [declared (append (map car decls) (map car dims) outer-names)]
              [new (for/list ([d (reverse (unbox ext))]
                              #:unless (memq (car d) declared))
                     d)])
         `(with-arrays ,(append decls (remove-duplicates new)) ,@body2))]
      ;; G = X Y^T: g[k1,k2] = row k1 of x . row k2 of y, the rows in
      ;; either order under the *
      [`(range-for (,(? symbol? k1) ,p1)
          (range-for (,(? symbol? k2) ,p2)
            (array-set! ,(? symbol? g) ,k1b ,k2b
                        (array-sum (* (row ,(? symbol? x) ,kx) (row ,(? symbol? y) ,ky))))))
       #:when (and (not (eq? k1 k2)) (eq? k1 k1b) (eq? k2 k2b)
                   (or (and (eq? kx k1) (eq? ky k2)) (and (eq? kx k2) (eq? ky k1)))
                   (mat? x dims) (mat? y dims)
                   (not (mentions? k1 p2)))
       (set! fired #t)
       (if (eq? kx k1)
           `(array-set! ,g (matmul ,x (transpose ,y)))
           `(array-set! ,g (matmul ,y (transpose ,x))))]
      ;; C = X V
      [`(range-for (,(? symbol? k) ,p)
          (array-set! ,(? symbol? c) ,kb (array-sum (* ,u ,v))))
       #:when (and (eq? k kb)
                   (or (and (match u [`(row ,(? symbol? x) ,(== k)) (mat? x dims)] [_ #f])
                            (not (mentions? k v)))
                       (and (match v [`(row ,(? symbol? x) ,(== k)) (mat? x dims)] [_ #f])
                            (not (mentions? k u)))))
       (set! fired #t)
       (match* (u v)
         [(`(row ,x ,_) _) #:when (not (mentions? k v)) `(array-set! ,c (matmul ,x ,v))]
         [(_ `(row ,x ,_)) `(array-set! ,c (matmul ,x ,u))])]
      ;; R -= X^T D  (or +=): r -= d[j] * row j of x, over j
      [`(range-for (,(? symbol? j) ,p)
          (,(and op (or 'array-dec! 'array-inc!)) ,(? symbol? r)
           (scale ,ex (row ,(? symbol? x) ,jb))))
       #:when (and (eq? j jb) (mat? x dims)
                   (let ([used (box '())]) (deindex ex (list j) used)))
       (let* ([used (box '())] [d (deindex ex (list j) used)])
         (set! fired #t)
         (set-box! extra (append (for/list ([v (unbox used)]) (list v (list p)))
                                 (unbox extra)))
         `(,op ,r (matmul (transpose ,x) ,d)))]
      ;; R -= D^T X  (or +=), the matrix residual: row k of r -= d[j,k]
      ;; * row j of x, over j and k
      [`(range-for (,(? symbol? j) ,p)
          (range-for (,(? symbol? k) ,q)
            (,(and op (or 'row-dec! 'row-inc!)) ,(? symbol? r) ,kb
             (scale ,ex (row ,(? symbol? x) ,jb)))))
       #:when (and (eq? j jb) (eq? k kb) (not (eq? j k)) (mat? x dims)
                   (not (mentions? j q))
                   (let ([used (box '())]) (deindex ex (list j k) used)))
       (let* ([used (box '())] [d (deindex ex (list j k) used)])
         (set! fired #t)
         (set-box! extra (append (for/list ([v (unbox used)]) (list v (list p q)))
                                 (unbox extra)))
         `(,(if (eq? op 'row-dec!) 'array-dec! 'array-inc!) ,r
           (matmul (transpose ,d) ,x)))]
      [(? pair?) (map (lambda (s) (walk s dims extra)) e)]
      [_ e]))
  (define out (walk e (decl-dims outer-decls) (box '())))
  (values out fired))

;; Derive one function body.  OUTPUTS is the list of its parameters
;; whose final contents a caller reads.  Returns the new body and the
;; firing log, or #f when nothing but the raising fired.
(define (derive-body body outputs)
  (define-values (decls wbody rebuild) (find-with-arrays body))
  (and decls
       (let* ([dims (decl-dims decls)]
              [exts (decl-extents decls)]
              [raised (raise-loops wbody dims exts)])
         (and raised
              (for/or ([vb (scratch-candidates raised)])
                ;; A scratch that is an output is restored; one that is
                ;; not is restored only if the body itself reads it
                ;; afterwards, which the driver decides ('auto).  The
                ;; coefficients are live whatever the caller sees.
                (define-values (derived log)
                  (derive-fixpoint/log wbody (car vb) (cdr vb)
                                       #:restore? (if (memq (car vb) outputs) #t 'auto)
                                       #:extents exts #:dims dims
                                       #:live-out (remove-duplicates
                                                   (cons (cdr vb) outputs))))
                (and (pair? (remove 'raise log))
                     (let-values ([(body mm?) (fold-matmul (tidy derived) decls)])
                       (cons (rebuild body)
                             (if mm? (append log '(matmul)) log)))))))))

;; ---- the file ----

;; FORMS is the program as read; OUTPUT-PARAMS maps a function name and
;; its parameter list to the parameters that are outputs.  Functions
;; that do not derive are returned as they were.
(define (derive-forms forms output-params)
  (define logs '())
  (define out
    (for/list ([f forms])
      (match f
        [`(define (,(? symbol? g) ,(? symbol? ps) ...) ,body ...)
         (match (derive-body body (output-params g ps))
           [(cons new-body log)
            (set! logs (cons (cons g log) logs))
            `(define (,g ,@ps) ,@new-body)]
           [_ f])]
        [_ f])))
  (derive-log (reverse logs))
  out)

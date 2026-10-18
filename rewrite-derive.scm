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
;;;;   scratch     the vector an update site decrements (or increments)
;;;;               by a scaled row -- (array-dec! V (scale D (row X J)))
;;;;               once the loops are raised -- and the coefficients the vector
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
         (only-in (file "rewrite-incremental.scm") walk-collect written-vars)
         (only-in (file "rewrite-invariant.scm") hoist-invariant-products memo-invariant-calls))

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
                [`(,(or 'array-dec! 'array-inc!) ,(? symbol? v)
                   (scale ,_ (,(or 'row 'col) ,_ ,(? symbol? j))))
                 (cons v j)]
                [`(,(or 'row-dec! 'row-inc! 'col-dec! 'col-inc!) ,(? symbol? v) ,_ ...
                   (scale ,_ (,(or 'row 'col) ,_ ,(? symbol? j))))
                 (cons v j)]
                [_ #f]))))
  (remove-duplicates
   (for*/list ([u updates]
               [e (walk-collect pair? raised)]
               #:when (match e
                        [`(,(or 'vector-set! 'array-set!) ,(? symbol? b) ,(== (cdr u)) ,_)
                         (not (eq? b (car u)))]
                        ;; the matrix or tensor coefficients of a row,
                        ;; column or fiber update, the direction's index
                        ;; at any axis (W[i,t] for the t-th column of
                        ;; H', say).  The restore sums the update
                        ;; coefficients themselves, so this pairing only
                        ;; picks the scratch out
                        [`(array-set! ,(? symbol? b) ,is ... ,_)
                         (and (memq (cdr u) is) (not (eq? b (car u))))]
                        [_ #f]))
     (cons (car u) (cadr e)))))

;; ---- one function ----

;; The first with-arrays in statement position of BODY, as
;; (values decls wbody rebuild) where (rebuild new-wbody) is BODY with
;; that form's body replaced; or #f when there is none.  A let whose
;; body holds it is entered, so a kernel may allocate its scratch
;; locally -- (let ((r (make-vector (* n p) 0.0))) (with-arrays ..)) --
;; and a scratch nothing reads after the sweep is then not restored.
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
      [(match (car rest) [`(let ,(? list?) ,_ ...) #t] [_ #f])
       (match-define `(let ,bs ,lbody ...) (car rest))
       (let-values ([(decls wbody rebuild) (find-with-arrays lbody)])
         (if decls
             (values decls wbody
                     (lambda (new)
                       (append (reverse pre)
                               (list `(let ,bs ,@(rebuild new)))
                               (cdr rest))))
             (loop (cons (car rest) pre) (cdr rest))))]
      [else (loop (cons (car rest) pre) (cdr rest))])))

;; (* p) for a rank-one table's cell count is what the driver writes;
;; the emitter wants the plain operand.
(define (tidy e)
  (match e
    [`(* ,x) (tidy x)]
    [(? pair?) (map tidy e)]
    [_ e]))

;; ---- the contractions ----
;;
;; The differencing writes its products cell by cell, in the algebra
;; one rank below the one they have:
;;   (range-for (k1 P) (range-for (k2 P)
;;     (array-set! G k1 k2 (array-sum (* (row X k1) (row X k2))))))
;;   (range-for (k P) (array-set! C k (array-sum (* (row X k) V))))
;;   (range-for (j P) (array-dec! R (scale E(j) (row X j))))
;; and the matrix and tensor shapes of the same, with more loops and
;; more fixed indices.  Each is one contraction -- numpy's einsum --
;; once every loop index, and the index the dot product sums over, is
;; named on the axis it runs over: the memo above is
;;   (array-set! C (contract (i) (k) (X k i) (V i)))
;; and folding it so is what lets --blas hand it to one BLAS call; the
;; algebra is unchanged, only spelled at its rank.  A view says which
;; axis the dot product runs over -- (row a j ..) is a along its last
;; axis with the others fixed, (col a j ..) along its first -- and
;; the two operands may be cut either way; a tensor scratch's fibers
;; are no different from a matrix's rows.  The contraction carries the
;; labels, and the lowering reads off where the summed ones sit which
;; call it is.  The coefficient D of the restore is E with the loop
;; indices taken out -- (vector-ref V j) is V -- so it may name a
;; vector the scope did not declare (the saved coefficients, say);
;; those get a declaration on the nested with-arrays whose body they
;; stand in.  Returns the folded body and whether anything folded.
(define (fold-matmul e outer-decls)
  (define fired #f)
  (define outer-names (map car outer-decls))
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
  ;; a nest of single-statement range-fors: its indices, their
  ;; extents, and the statement inside
  (define (peel e)
    (let loop ([e e] [ks '()] [es '()])
      (match e
        [`(range-for (,(? symbol? k) ,n) ,body) (loop body (cons k ks) (cons n es))]
        [_ (values (reverse ks) (reverse es) e)])))
  (define (rank-of a dims) (let ([d (assq a dims)]) (and d (length (cadr d)))))
  ;; an operand of a dot product as the contraction names it, (a l ..):
  ;; a view of a declared array with K on the axis it runs along, or a
  ;; bare vector, which is (a K)
  (define (labels o k dims)
    (match o
      [`(row ,(? symbol? a) ,(? symbol? js) ...)
       #:when (equal? (rank-of a dims) (+ 1 (length js)))
       `(,a ,@js ,k)]
      [`(col ,(? symbol? a) ,(? symbol? js) ...)
       #:when (equal? (rank-of a dims) (+ 1 (length js)))
       `(,a ,k ,@js)]
      [(? symbol? a) `(,a ,k)]
      [_ #f]))
  (define (same-set? a b)
    (and (= (length a) (length b))
         (equal? (sort a symbol<?) (sort b symbol<?))))
  ;; g[ks..] = sum over the dot product's index of u * v: the memo
  ;; build and the Gram, at any rank
  (define (memo-fold ks stmt dims)
    (match stmt
      [`(array-set! ,(? symbol? g) ,gks ... (array-sum (* ,u ,v)))
       #:when (and (equal? gks ks) (equal? (rank-of g dims) (length ks)))
       (let* ([k (gensym 'k)] [lu (labels u k dims)] [lv (labels v k dims)])
         (and lu lv
              (let ([free (filter (lambda (l) (not (eq? l k))) (append (cdr lu) (cdr lv)))])
                (and (same-set? free ks)
                     `(array-set! ,g (contract (,k) ,ks ,lu ,lv))))))]
      [_ #f]))
  ;; the restore: the fibers of r at kts.. -= d[ks..] * (view x js..)
  ;; over the loops ks.., js.. being the summed indices
  (define (restore-fold ks es stmt dims extra)
    (match stmt
      [`(,(and op (or 'array-dec! 'array-inc! 'row-dec! 'row-inc! 'col-dec! 'col-inc!))
         ,(? symbol? r) ,kts ... (scale ,ex ,xv))
       #:when (and (andmap (lambda (t) (memq t ks)) kts)
                   (= (length kts) (length (remove-duplicates kts)))
                   (let ([used (box '())]) (deindex ex ks used)))
       (let* ([i (gensym 'i)]
              [lx (labels xv i dims)]
              [summed (filter (lambda (l) (not (memq l kts))) ks)]
              [js (and lx (filter (lambda (l) (not (eq? l i))) (cdr lx)))])
         (and lx (pair? summed) (same-set? js summed)
              (equal? (rank-of r dims)
                      (+ 1 (length kts)))
              (let* ([used (box '())] [d (deindex ex ks used)]
                     [lr (match op
                           [(or 'array-dec! 'array-inc!) `(,r ,i)]
                           [(or 'row-dec! 'row-inc!) `(,r ,@kts ,i)]
                           [_ `(,r ,i ,@kts)])]
                     [op2 (if (memq op '(array-dec! row-dec! col-dec!)) 'array-dec! 'array-inc!)])
                (set-box! extra (append (for/list ([v (unbox used)]) (list v es))
                                        (unbox extra)))
                `(,op2 ,r (contract ,summed ,(cdr lr) (,d ,@ks) ,lx)))))]
      [_ #f]))
  (define (walk e dims extra)
    (match e
      [`(with-arrays ,decls ,body ...)
       (let* ([inner (append (for/list ([d decls]) (list (car d) (cadr d))) dims)]
              [ext (box '())]
              [body2 (map (lambda (b) (walk b inner ext)) body)]
              [declared (append (map car decls) (map car dims) outer-names)]
              [new (for/list ([d (reverse (unbox ext))]
                              #:unless (memq (car d) declared))
                     d)])
         `(with-arrays ,(append decls (remove-duplicates new)) ,@body2))]
      [`(range-for (,(? symbol? _) ,_) ,_)
       (let-values ([(ks es stmt) (peel e)])
         (let ([r (or (memo-fold ks stmt dims) (restore-fold ks es stmt dims extra))])
           (cond [r (set! fired #t) r]
                 [else (map (lambda (s) (walk s dims extra)) e)])))]
      [(? pair?) (map (lambda (s) (walk s dims extra)) e)]
      [_ e]))
  (define out (walk e (for/list ([d outer-decls]) (list (car d) (cadr d))) (box '())))
  (values out fired))

;; ---- a residual fill distributed through the memo ----
;;
;; A kernel that forms its scratch by whole-array assignments and then
;; sweeps it -- NMF's half step:
;;   (array-set! r x) (array-dec! r (matmul w (transpose ht)))
;; -- reaches the derivation's memo as a contraction over r,
;;   (array-set! c (contract (s) (i t) (r i s) (v s t))),
;; and r is read nowhere else in the derived body.  The contraction is
;; linear in r, so it distributes over the fill:
;;   c = contract(x, v) - contract(w ht', v),
;; and the second term is w times (contract (s) (u t) (ht s u) (v s t)),
;; a table the derivation has already built when v is ht -- the Gram.
;; So the memo becomes x v - w g, two products that never touch r, and
;; the fill is dead: scikit-learn's XHt - W HHt.  The rule fires only
;; when the table is found among the hoisted contractions (same
;; operands, labels renamed) and nothing between the fill and the memo
;; writes r, x, w or ht.  Returns the body and the names no longer read.
(define (contract-key c)
  ;; a contraction's operands, labels renamed by role: free labels by
  ;; their position in the result, summed ones by first appearance
  (match c
    [`(contract ,ks ,ys ,oa ,ob)
     (define (ren l)
       (cond [(index-of ys l) => (lambda (i) (string->symbol (format "Y~a" i)))]
             [(index-of ks l) => (lambda (i) (string->symbol (format "K~a" i)))]
             [else l]))
     (sort (list (map ren oa) (map ren ob))
           (lambda (a b) (string<? (format "~s" a) (format "~s" b))))]
    [_ #f]))

(define (distribute-fills body)
  (define freed '())
  (define (refs v e) (length (walk-collect (lambda (x) (eq? x v)) e)))
  ;; the hoisted tables of the derived body: (g . key)
  (define tables
    (for/list ([e (walk-collect pair? body)]
               #:when (match e [`(array-set! ,(? symbol?) (contract ,_ ...)) #t] [_ #f]))
      (cons (cadr e) (contract-key (caddr e)))))
  ;; the memo statement over R inside STMT, rewritten, or #f
  (define (rewrite-memo stmt r x w b)
    (define hit #f)
    (define new
      (let go ([e stmt])
        (match e
          [`(array-set! ,(? symbol? c) (contract (,s) (,i ,t) (,(== r) ,i2 ,s2) (,v ,s3 ,t2)))
           #:when (and (not hit) (eq? i i2) (eq? s s2) (eq? s s3) (eq? t t2) (symbol? v))
           (let* ([u (gensym 'u)]
                  [key (contract-key `(contract (,s) (,u ,t) (,b ,s ,u) (,v ,s ,t)))]
                  [g (for/or ([tb tables]) (and (equal? (cdr tb) key) (car tb)))])
             (cond
               [g (set! hit #t)
                  `(begin (array-set! ,c (contract (,s) (,i ,t) (,x ,i ,s) (,v ,s ,t)))
                          (array-dec! ,c (contract (,u) (,i ,t) (,w ,i ,u) (,g ,u ,t))))]
               [else e]))]
          [(? pair?) (map go e)]
          [_ e])))
    (and hit new))
  ;; statements before the memo, inside STMT, in document order
  (define (before-memo stmt r)
    (let/ec k
      (let go ([e stmt] [acc '()])
        (match e
          [`(array-set! ,(? symbol?) (contract ,_ ,_ (,(== r) ,_ ...) ,_)) (k (reverse acc))]
          [(? list?)
           (for/fold ([acc acc]) ([x e])
             (go x (if (and (pair? x) (memq (car x) '(array-set! array-inc! array-dec! vector-set! set!)))
                       (cons x acc) acc)))]
          [_ acc]))
      '()))
  (define (walk e)
    (match e
      [(list-rest (? (lambda (h) (memq h '(begin let with-arrays range-for)))) _)
       (let loop ([pre '()] [rest (map walk e)])
         (match rest
           [(list* `(array-set! ,(? symbol? r) ,(? symbol? x))
                   `(array-dec! ,(? symbol? r2) (matmul ,(? symbol? w) (transpose ,(? symbol? b))))
                   next more)
            #:when (eq? r r2)
            (let* ([written (written-vars (before-memo next r))]
                   [clean (not (for/or ([v (list r x w b)]) (set-member? written v)))]
                   [new (and clean (rewrite-memo next r x w b))])
              (if (and new (zero? (refs r new)) (zero? (refs r more)))
                  (begin (set! freed (cons r freed))
                         (append (reverse pre) (cons new more)))
                  (loop (cons (car rest) pre) (cdr rest))))]
           [(cons a d) (loop (cons a pre) d)]
           ['() (reverse pre)]))]
      [(? pair?) (map walk e)]
      [_ e]))
  ;; the body is a statement list itself, walked as a begin's
  (define out (cdr (walk `(begin ,@body))))
  (values out freed))

;; After the guard: a let-bound scratch the derived branch no longer
;; reads is allocated in the original branch only.
(define (sink-bindings body freed)
  (define (in-derived? v e) (pair? (walk-collect (lambda (x) (eq? x v)) e)))
  (let go ([e body])
    (match e
      [`(let ,bs (with-arrays ,decls (if ,c (begin ,d ...) (begin ,o ...))))
       (let* ([moved (filter (lambda (b) (and (memq (car b) freed)
                                              (not (in-derived? (car b) d))))
                             bs)]
              [kept (filter (lambda (b) (not (memq b moved))) bs)])
         (if (null? moved)
             e
             (let ([inner `(with-arrays ,decls
                             (if ,c (begin ,@d) (let ,moved (begin ,@o))))])
               (if (null? kept) inner `(let ,kept ,inner)))))]
      [(? pair?) (map go e)]
      [_ e])))

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
                     (let*-values ([(body mm?) (fold-matmul (tidy derived) decls)]
                                   [(body freed) (distribute-fills body)])
                       (cons (sink-bindings
                              (rebuild (guard-by-shape body wbody
                                                       (update-matrix raised (car vb))
                                                       dims))
                              freed)
                             (append log (if mm? '(matmul) '())
                                     (if (pair? freed) '(distribute) '())
                                     '(guard))))))))))

;; The matrix whose rows (or columns) update scratch V in the raised
;; sweep, as (X . view): X and row of (array-dec! V (scale D (row X J)))
;; or of the increment, X and col when the direction is a column.
(define (update-matrix raised v)
  (for/or ([e (walk-collect pair? raised)])
    (match e
      [`(,(or 'array-dec! 'array-inc!) ,(== v)
         (scale ,_ (,(and view (or 'row 'col)) ,(? symbol? x) ,_)))
       (cons x view)]
      [`(,(or 'row-dec! 'row-inc! 'col-dec! 'col-inc!) ,(== v) ,_ ...
         (scale ,_ (,(and view (or 'row 'col)) ,(? symbol? x) ,_)))
       (cons x view)]
      [_ #f])))

;; The differencing trades the scratch, one direction of X long (N
;; cells, or NTASK by N), for a memo of X times it, one cell per
;; direction (P, or NTASK by P), plus the P-by-P Gram built once.  That
;; pays only when P < N, and P and N are run-time values, so the derived
;; body runs under (if (< P N) DERIVED ORIGINAL) and a wide X keeps the
;; sweep as written.  Which declared extent is which depends on the
;; view: a row of a (p n) matrix is n long and there are p of them; a
;; column of an (n p) one likewise.  This is scikit-learn's
;; precompute='auto' rule, the one lasso-auto.scm writes by hand.
(define (guard-by-shape derived original x+view dims)
  (match (and x+view (assq (car x+view) dims))
    [`(,_ (,d0 ,d1))
     (let-values ([(p n) (if (eq? (cdr x+view) 'row) (values d0 d1) (values d1 d0))])
       `((if (< ,p ,n) (begin ,@derived) (begin ,@original))))]
    [_ derived]))

;; ---- the file ----

;; FORMS is the program as read; OUTPUT-PARAMS maps a function name and
;; its parameter list to the parameters that are outputs.  Functions
;; that do not derive are returned as they were.
(define (derive-forms forms output-params)
  (define logs '())
  (define defs
    (for/hasheq ([f forms]
                 #:when (match f [`(define (,(? symbol?) ,_ ...) ,_ ...) #t] [_ #f]))
      (values (caadr f) f)))
  (define out
    (append*
     (for/list ([f forms])
       (match f
         [`(define (,(? symbol? g) ,(? symbol? ps) ...) ,body0 ...)
          ;; work on loop-invariant data first (rewrite-invariant.scm):
          ;; products tabulated, then pure costly calls memoised; the
          ;; differencing then runs on what is left
          (define-values (body1 inv?) (hoist-invariant-products body0 defs))
          (define-values (body memo? helpers) (memo-invariant-calls body1 defs g))
          (define pre (append (if inv? '(invariant) '()) (if memo? '(memo) '())))
          (append
           helpers
           (list
            (match (derive-body body (output-params g ps))
              [(cons new-body log)
               (set! logs (cons (cons g (append pre log)) logs))
               `(define (,g ,@ps) ,@new-body)]
              [_ (cond [(pair? pre) (set! logs (cons (cons g pre) logs))
                                    `(define (,g ,@ps) ,@body)]
                       [else f])])))]
         [_ (list f)]))))
  (derive-log (reverse logs))
  out)

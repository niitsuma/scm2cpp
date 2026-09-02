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
                     (cons (rebuild (tidy derived)) log)))))))

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

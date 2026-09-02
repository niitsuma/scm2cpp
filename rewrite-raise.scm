#lang racket
;;;; Loop raising: the front door of the driver.  Everything after the
;;;; differencing pass speaks the array algebra -- array-dec!,
;;;; array-sum, row -- but a kernel a person writes in plain Scheme
;;;; says do, vector-set! and flat indices.  This pass lifts the plain
;;;; text into the algebra, so the derivation no longer requires its
;;;; input to have been written in the layer.
;;;;
;;;; Every rule is the inverse of an expansion the layer's macros
;;;; perform, applied only where the expansion is exactly what stands
;;;; there, so raising is value-identical bit for bit: the raised
;;;; forms expand back to the same loops in the same order.  The one
;;;; place that needs care is the accumulator seed -- a fold seeded
;;;; with the same 0.0 the accumulator started from IS the original
;;;; sum, so the binding takes the fold directly and no 0.0 + x is
;;;; ever introduced.
;;;;
;;;;   R1  the canonical counting do becomes range-for;
;;;;   R2  a flat index w*N + i becomes a two-axis access, licensed
;;;;       by the declared dims;
;;;;   R3  an accumulation loop becomes a fold of the element view;
;;;;   R4  a self-update loop becomes array-inc!/array-dec! of it, or
;;;;       row-inc!/row-dec! when it walks one row of a declared matrix;
;;;;   R5  an accumulator initialized to zero and bumped once folds
;;;;       into its own binding;
;;;;   R6  a let binding read exactly once by the fill it wraps
;;;;       disappears into it;
;;;;   R7  a slice spanning a vector's whole declared extent is the
;;;;       vector, licensed by the extents table.
;;;;
;;;; Rules apply bottom-up to a fixpoint; one driver firing raises
;;;; everything there is to raise.

(require (only-in (file "rewrite-incremental.scm")
                  walk-collect pure? subst)
         (only-in (file "rewrite-normalize.scm") elem->vexpr))

(provide raise-loops)

(define (occurrences e v)
  (length (walk-collect (lambda (x) (eq? x v)) e)))

(define (raise-step e dims base-exts)
  (define (row-width a)
    (cond [(assq a dims)
           => (lambda (d) (and (= 2 (length (cadr d))) (cadr (cadr d))))]
          [else #f]))
  (match e
    ;; R1: the counting do
    [`(do ((,(? symbol? i) 0 (+ ,i2 1))) ((= ,i3 ,N)) ,body ...)
     #:when (and (eq? i i2) (eq? i i3))
     `(range-for (,i ,N) ,@body)]
    ;; R2: flat indices, both orders of the sum
    [`(vector-ref ,(? symbol? a) (+ (* ,w ,N) ,i))
     #:when (equal? (row-width a) N)
     `(array-ref ,a ,w ,i)]
    [`(vector-ref ,(? symbol? a) (+ ,i (* ,w ,N)))
     #:when (equal? (row-width a) N)
     `(array-ref ,a ,w ,i)]
    [`(vector-set! ,(? symbol? a) (+ (* ,w ,N) ,i) ,v)
     #:when (equal? (row-width a) N)
     `(array-set! ,a ,w ,i ,v)]
    [`(vector-set! ,(? symbol? a) (+ ,i (* ,w ,N)) ,v)
     #:when (equal? (row-width a) N)
     `(array-set! ,a ,w ,i ,v)]
    ;; R3: accumulation
    [`(range-for (,(? symbol? i) ,N)
        (set! ,(? symbol? acc) ,rhs))
     #:when (match rhs
              [`(+ ,a ,b) (or (eq? a acc) (eq? b acc))]
              [_ #f])
     (let* ([term (match rhs
                    [`(+ ,a ,b) (if (eq? a acc) b a)])]
            [v (and (zero? (occurrences term acc))
                    (elem->vexpr term i N))])
       (if v `(set! ,acc (+ ,acc (array-sum ,v))) e))]
    ;; R4: self-update
    [`(range-for (,(? symbol? i) ,N)
        (vector-set! ,(? symbol? a) ,i2 ,rhs))
     #:when (eq? i i2)
     (let-values
         ([(op term)
           (match rhs
             [`(- (vector-ref ,a2 ,i3) ,t)
              #:when (and (eq? a2 a) (eq? i3 i))
              (values 'array-dec! t)]
             [`(+ (vector-ref ,a2 ,i3) ,t)
              #:when (and (eq? a2 a) (eq? i3 i))
              (values 'array-inc! t)]
             [`(+ ,t (vector-ref ,a2 ,i3))
              #:when (and (eq? a2 a) (eq? i3 i))
              (values 'array-inc! t)]
             [_ (values #f #f)])])
       (if (and op (zero? (occurrences term a)))
           (let ([v (elem->vexpr term i N)])
             (if v `(,op ,a ,v) e))
           e))]
    ;; R4, the row shape: a[t,i] <- a[t,i] -+ term over the row's
    ;; width, once R2 has read the flat indices as two axes
    [`(range-for (,(? symbol? i) ,N)
        (array-set! ,(? symbol? a) ,t ,i2 ,rhs))
     #:when (and (eq? i i2) (equal? (row-width a) N))
     (let-values
         ([(op term)
           (match rhs
             [`(- (array-ref ,a2 ,t2 ,i3) ,u)
              #:when (and (eq? a2 a) (equal? t2 t) (eq? i3 i))
              (values 'row-dec! u)]
             [`(+ (array-ref ,a2 ,t2 ,i3) ,u)
              #:when (and (eq? a2 a) (equal? t2 t) (eq? i3 i))
              (values 'row-inc! u)]
             [`(+ ,u (array-ref ,a2 ,t2 ,i3))
              #:when (and (eq? a2 a) (equal? t2 t) (eq? i3 i))
              (values 'row-inc! u)]
             [_ (values #f #f)])])
       (if (and op (zero? (occurrences term a)))
           (let ([v (elem->vexpr term i N)])
             (if v `(,op ,a ,t ,v) e))
           e))]
    ;; R5: the accumulator folds into its binding.  The seed must be
    ;; the fold's own zero and the folded value must not read any
    ;; sibling binder -- let binds in parallel.
    [`(let ,binds (set! ,(? symbol? acc) (+ ,acc2 ,S)) ,body ...)
     #:when (and (eq? acc acc2)
                 (assq acc binds)
                 (member (cadr (assq acc binds)) '(0.0 0))
                 (pure? S)
                 (zero? (occurrences S acc))
                 (for/and ([b binds])
                   (zero? (occurrences S (car b)))))
     `(let ,(for/list ([b binds])
              (if (eq? (car b) acc) (list acc S) b))
        ,@body)]
    ;; R6: a binding the fill reads once
    [`(let ((,(? symbol? v) ,E))
        (,(and setter (or 'vector-set! 'array-set!)) ,a ,r ...))
     #:when (and (pure? E)
                 (= 1 (occurrences (cons setter r) v))
                 ;; binder name plus that one read and nothing else
                 (= 2 (occurrences e v)))
     `(,setter ,a ,@(map (lambda (x) (subst v E x)) r))]
    ;; R7: the whole-extent slice
    [`(slice ,(? symbol? a) 0 (+ 0 ,N))
     #:when (cond [(assq a base-exts) => (lambda (b) (equal? (cdr b) N))]
                  [else #f])
     a]
    [_ e]))

(define (tree-map f e)
  (f (if (list? e) (map (lambda (x) (tree-map f x)) e) e)))

;; Everything raisable, raised: iterate the rules to a fixpoint and
;; report #f when nothing moved, so the driver's firing is exactly
;; "the program was not yet in the algebra".
(define (raise-loops stmts dims base-exts)
  (let loop ([s stmts] [fuel 50])
    (let ([s2 (tree-map (lambda (e) (raise-step e dims base-exts)) s)])
      (cond [(equal? s2 s) (and (not (equal? s stmts)) s)]
            [(zero? fuel) s2]
            [else (loop s2 (sub1 fuel))]))))

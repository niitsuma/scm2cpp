#lang racket
;;;; The unified cost model the per-rule gates approximate piecewise:
;;;; one polynomial over loop extents per program, comparable either
;;;; symbolically -- every extent at least one -- or numerically when
;;;; concrete sizes are known.
;;;;
;;;; The count is operation-shaped, not cycle-accurate: a statement
;;;; costs one per execution, a fold costs the length of what it
;;;; folds, a whole-vector update likewise, and an allocation costs
;;;; its size -- zero-initialization is a real pass over the memory,
;;;; which is exactly the term the benchmark kept charging us for.
;;;; Space is therefore inside the same polynomial rather than a
;;;; second objective: a table that is never worth its own
;;;; initialization never looks profitable.
;;;;
;;;; Symbolic comparison is deliberately partial.  p*n against
;;;; p*nobs has no winner until someone relates n to nobs, and the
;;;; comparator says so by returning false both ways rather than
;;;; guessing; numeric evaluation decides such cases when the driver
;;;; is given sizes.

(require (only-in (file "rewrite-incremental.scm") walk-collect))

(provide program-cost program-space poly-add poly<=? poly<? poly-eval expr->poly)

;; a polynomial: alist of (monomial . coeff), monomial a sorted list
;; of symbols with repetition for powers, coeff a positive rational

(define (poly-norm ps)
  (for/fold ([acc '()]) ([p ps])
    (match-define (cons m c) p)
    (cond [(zero? c) acc]
          [(assoc m acc)
           => (lambda (q) (cons (cons m (+ c (cdr q)))
                                (remove q acc)))]
          [else (cons p acc)])))

(define (poly-const k) (if (zero? k) '() (list (cons '() k))))
(define (poly-add . ps) (poly-norm (apply append ps)))
(define (poly-mul a b)
  (poly-norm
   (for*/list ([x a] [y b])
     (cons (sort (append (car x) (car y)) symbol<?)
           (* (cdr x) (cdr y))))))

;; extents and sizes to polynomials; anything outside the affine
;; vocabulary becomes one opaque symbol per distinct expression, so
;; unknown against itself still cancels
(define opaque (make-hash))
(define (expr->poly e)
  (match e
    [(? number?) (poly-const e)]
    [(? symbol?) (list (cons (list e) 1))]
    [`(+ ,a ...) (apply poly-add (map expr->poly a))]
    [`(- ,a ,b) (poly-add (expr->poly a)
                          (poly-mul (poly-const -1) (expr->poly b)))]
    [`(* ,a ...) (for/fold ([acc (poly-const 1)]) ([x a])
                   (poly-mul acc (expr->poly x)))]
    [_ (list (cons (list (hash-ref! opaque e
                                    (lambda () (gensym 'len))))
             1))]))

;; length of a vector expression, from the declared shapes
(define (vlen e dims base-exts)
  (match e
    [`(row ,a ,_)
     (cond [(assq a dims) => (lambda (d) (expr->poly (cadr (cadr d))))]
           [else (expr->poly (list 'len-of a))])]
    [`(slice ,a ,lo ,hi)
     (poly-add (expr->poly hi) (poly-mul (poly-const -1) (expr->poly lo)))]
    [(? symbol? a)
     (cond [(assq a base-exts) => (lambda (b) (expr->poly (cdr b)))]
           [(assq a dims) => (lambda (d) (expr->poly (car (cadr d))))]
           [else (expr->poly (list 'len-of a))])]
    [`(scale ,_ ,v) (vlen v dims base-exts)]
    [`(,(or '+ '- '*) ,u ,v) (vlen u dims base-exts)]
    [_ (expr->poly (list 'len-of e))]))

;; folds and whole-vector updates hiding inside an expression
(define (expr-cost e dims base-exts)
  (for/fold ([acc (poly-const 0)])
            ([x (walk-collect pair? e)])
    (match x
      [`(,(or 'array-sum 'array-dot) ,v ,_ ...)
       (poly-add acc (vlen v dims base-exts))]
      [`(array-reduce ,_ ,_ ,v) (poly-add acc (vlen v dims base-exts))]
      [_ acc])))

;; The other objective: cells allocated, as a polynomial over the same
;; extents. Time already charges an allocation its size once (the
;; zero-initialization pass); this counts the cells themselves, so a
;; driver in memory mode can hold candidates to it first and use time
;; only as the tiebreak. A candidate produced by lower-replacement
;; declares its table twice -- once in the let's make-vector, once in
;; with-arrays -- and both are counted; the factor of two is the same
;; on every side of a comparison, and comparisons are all this is for.
(define (program-space stmts dims base-exts)
  (for/fold ([acc (poly-const 0)])
            ([x (walk-collect pair? stmts)])
    (match x
      [`(make-vector ,size ,_ ...)
       (poly-add acc (expr->poly size))]
      [`(with-arrays ,decls ,_ ...)
       (poly-add acc
                 (apply poly-add
                        (for/list ([d decls])
                          (for/fold ([q (poly-const 1)]) ([dim (cadr d)])
                            (poly-mul q (expr->poly dim))))))]
      [_ acc])))

(define (program-cost stmts dims base-exts)
  (define (seq b) (apply poly-add (map go b)))
  (define (go e)
    (match e
      [`(range-for (,_ ,n) ,b ...)
       (poly-mul (expr->poly n) (seq b))]
      [`(range-for (,_ ,lo ,hi) ,b ...)
       (poly-mul (poly-add (expr->poly hi)
                           (poly-mul (poly-const -1) (expr->poly lo)))
                 (seq b))]
      [`(begin ,b ...) (seq b)]
      [`(with-arrays ,_ ,b ...) (seq b)]
      [`(let ,binds ,b ...)
       (poly-add (apply poly-add
                        (for/list ([bd binds])
                          (match bd
                            [`(,_ (make-vector ,size ,_ ...))
                             (expr->poly size)]
                            [`(,_ ,e) (go e)]
                            [_ (poly-const 0)])))
                 (seq b))]
      [`(if ,c ,t ,f)
       (poly-add (poly-const 1) (go t) (go f))]
      [`(,(or 'array-inc! 'array-dec!) ,_ ,v)
       (poly-add (poly-const 1) (vlen v dims base-exts)
                 (expr-cost v dims base-exts))]
      [(? pair?)
       (poly-add (poly-const 1) (expr-cost e dims base-exts))]
      [_ (poly-const 0)]))
  (seq stmts))

;; A <= B for every valuation with all symbols >= 1: greedily match
;; each monomial of A into monomials of B whose symbol multisets
;; dominate it, consuming coefficient budget.  Partial by design.
(define (mono-dominates? small big)
  (let loop ([s small] [b big])
    (cond [(null? s) #t]
          [(null? b) #f]
          [(eq? (car s) (car b)) (loop (cdr s) (cdr b))]
          [else (loop s (cdr b))])))

(define (poly<=? a b)
  (let loop ([a (sort a > #:key (lambda (p) (length (car p))))]
             [b b])
    (cond [(null? a) #t]
          [else
           (match-define (cons m c) (car a))
           (let scan ([b b] [seen '()] [c c])
             (cond [(zero? c) (loop (cdr a) (append seen b))]
                   [(null? b) #f]
                   [(and (positive? (cdar b))
                         (mono-dominates? m (caar b)))
                    (let ([take (min c (cdar b))])
                      (scan (cdr b)
                            (cons (cons (caar b) (- (cdar b) take)) seen)
                            (- c take)))]
                   [else (scan (cdr b) (cons (car b) seen) c)]))])))

(define (poly<? a b) (and (poly<=? a b) (not (poly<=? b a))))

;; numeric evaluation; #f when a symbol is missing from the sizes
(define (poly-eval p env)
  (for/fold ([acc 0]) ([q p])
    #:break (not acc)
    (let ([v (for/fold ([v (cdr q)]) ([s (car q)])
               #:break (not v)
               (let ([x (assq s env)])
                 (and x v (* v (cdr x)))))])
      (and v acc (+ acc v)))))

#lang racket
;;;; The normalization half of the fixpoint driver: cost-neutral
;;;; rewrites that expose const folds the improvement rules can then
;;;; table.  Nothing here decides representation; it only changes what
;;;; a fold looks like.
;;;;
;;;; Inlining.  A pure fill loop
;;;;     (range-for (w P) (range-for (i N) (array-set! xd w i E)))
;;;; defines xd elementwise, and a read of xd inside a fold candidate
;;;; may take the definition's place.  A scalar read substitutes
;;;; directly.  A row read (row xd j) needs the element expression
;;;; re-expressed as a whole-vector view, and the existing algebra
;;;; already has the words for it: a shifted read ps[i+c] over extent N
;;;; is (slice ps c (+ c N)), a scalar factor is scale, and +/- carry
;;;; over.  The moving-average column (ps[t] - ps[t-w])/w comes out as
;;;; scale of a difference of two slices -- no new form is introduced.
;;;; Only reads whose index is the loop variable plus an invariant
;;;; offset qualify; anything else refuses.
;;;;
;;;; Distribution.  Inside each fold body, elementwise products
;;;; distribute over +/- and scale pulls out; the sum then pushes
;;;; through what remains.  On the inlined Gram element the four
;;;; lag-sum terms of the covariance kernel's build-S appear, each an
;;;; (array-sum (* (slice ps a ..) (slice ps b ..))) ready for the
;;;; improvement rules to table.  Distribution is exact over the reals
;;;; and reassociates floating point, the same standing the memo rules
;;;; have: same value, different rounding.
;;;;
;;;; The licence to use any of this is numeric, not syntactic: a
;;;; self-test inlines and normalizes a small concrete instance and
;;;; compares against direct evaluation, and every entry point refuses
;;;; when it fails -- the same arrangement the squared-norm catalog
;;;; entry uses.

(require (only-in (file "rewrite-incremental.scm")
                  walk-collect free-symbols pure? subst))

(provide collect-fill-defs inline-normalize normalize-fold)

;; ---------------- fill-loop definitions ----------------

;; A definition is (name (index ...) (extent ...) elem-expr): a straight
;; range-for nest whose single statement sets name at exactly the nest's
;; binders, in order.  Rank one or two.
(define (collect-fill-defs stmts)
  (filter values
          (for/list ([s (walk-collect pair? stmts)])
            (match s
              [`(range-for (,(? symbol? i) ,n)
                  (,(or 'vector-set! 'array-set!) ,(? symbol? a) ,i2 ,e))
               #:when (eq? i i2)
               (and (pure? e) (list a (list i) (list n) e))]
              [`(range-for (,(? symbol? w) ,p)
                  (range-for (,(? symbol? i) ,n)
                    (array-set! ,(? symbol? a) ,w2 ,i2 ,e)))
               #:when (and (eq? w w2) (eq? i i2))
               (and (pure? e) (list a (list w i) (list p n) e))]
              [_ #f]))))

;; ---------------- shifted reads become slices ----------------

;; The index must be the element variable plus an invariant offset:
;; occurrences of i exactly once, never under a *, /, or the right arm
;; of a -, so the coefficient is one.  The offset is the index with i
;; at zero.
(define (shift-offset idx i)
  (define (occurrences e)
    (length (walk-collect (lambda (x) (eq? x i)) e)))
  (define (coeff-one? e)
    (match e
      [(== i) #t]
      [`(+ ,a ,b) (if (> (occurrences a) 0) (coeff-one? a) (coeff-one? b))]
      [`(- ,a ,b) (and (= 0 (occurrences b)) (coeff-one? a))]
      [_ #f]))
  (define (simp e)
    (match e
      [`(+ ,a 0) (simp a)] [`(+ 0 ,a) (simp a)] [`(- ,a 0) (simp a)]
      [`(,op ,a ,b) `(,op ,(simp a) ,(simp b))]
      [_ e]))
  (and (= 1 (occurrences idx)) (coeff-one? idx)
       (simp (subst i 0 idx))))

;; Element expression to whole-vector view over extent n: reads of the
;; element variable become slices, invariant factors become scale, +/-
;; carry through.  #f whenever a shape outside that language shows up.
(define (elem->vexpr e i n)
  (define (invariant? x) (null? (walk-collect (lambda (y) (eq? y i)) x)))
  (let go ([e e])
    (match e
      [`(vector-ref ,(? symbol? v) ,idx)
       (let ([c (shift-offset idx i)])
         (and c `(slice ,v ,c (+ ,c ,n))))]
      [`(+ ,a ,b) (let ([va (go a)] [vb (go b)]) (and va vb `(+ ,va ,vb)))]
      [`(- ,a ,b) (let ([va (go a)] [vb (go b)]) (and va vb `(- ,va ,vb)))]
      [`(* ,(? invariant? s) ,a) (let ([va (go a)]) (and va `(scale ,s ,va)))]
      [`(* ,a ,(? invariant? s)) (let ([va (go a)]) (and va `(scale ,s ,va)))]
      [`(/ ,a ,(? invariant? s))
       (let ([va (go a)]) (and va `(scale (/ 1.0 ,s) ,va)))]
      [_ #f])))

;; ---------------- inlining reads of defined arrays ----------------

(define (tree-map f e)
  (f (if (list? e) (map (lambda (x) (tree-map f x)) e) e)))

;; A bare array symbol inside a fold body is a whole-vector operand --
;; the scalar positions there are scale's first argument and index
;; expressions, and the walk never descends into either.  When such a
;; symbol has a rank-one fill definition, its whole-vector view takes
;; its place: resid filled by resid[i] = y[i] becomes (slice y 0 n).
;; A definition with no expressible view stays bare; the downstream
;; lowering then refuses and the speculation rolls back, so nothing
;; is poisoned by leaving it.
(define (inline-bare expr defs)
  (define (view a)
    (match (assq a defs)
      [(list _ (list i) (list n) el) (elem->vexpr el i n)]
      [_ #f]))
  (define (vex e)
    (match e
      [(? symbol? a) (or (view a) e)]
      [`(scale ,s ,v) `(scale ,s ,(vex v))]
      [`(,(and op (or '+ '- '*)) ,a ,b) `(,op ,(vex a) ,(vex b))]
      [_ e]))
  (tree-map
   (lambda (x)
     (match x
       [`(array-sum ,b) `(array-sum ,(vex b))]
       [`(array-dot ,a ,b) `(array-dot ,(vex a) ,(vex b))]
       [_ x]))
   expr))

;; Replace reads of defined arrays inside EXPR: scalar reads substitute
;; the element expression, row reads substitute its whole-vector view.
;; A row read that cannot be viewed poisons the result (#f): a half
;; inlined fold is not worth normalizing.
(define (inline-defs expr defs)
  (define failed #f)
  (define out
    (tree-map
     (lambda (x)
       (match x
         [`(vector-ref ,(? symbol? a) ,idx)
          (match (assq a defs)
            [(list _ (list i) _ e) (subst i idx e)]
            [_ x])]
         [`(array-ref ,(? symbol? a) ,i1 ,i2)
          (match (assq a defs)
            [(list _ (list w i) _ e) (subst w i1 (subst i i2 e))]
            [_ x])]
         [`(row ,(? symbol? a) ,j)
          (match (assq a defs)
            [(list _ (list w i) (list _ n) e)
             (or (elem->vexpr (subst w j e) i n)
                 (begin (set! failed #t) x))]
            [_ x])]
         [_ x]))
     expr))
  (and (not failed) out))

;; ---------------- distribution ----------------

;; One bottom-up pass of the vector-algebra rules; iterate to fixpoint.
;; The rules only see vexpr shapes -- scale heads, elementwise
;; products, sums pushed over +/- -- so scalar arithmetic elsewhere in
;; the expression is left exactly as written.
(define (norm-step e)
  (tree-map
   (lambda (x)
     (match x
       [`(array-dot ,u ,v) `(array-sum (* ,u ,v))]
       [`(array-sum (+ ,a ,b)) `(+ (array-sum ,a) (array-sum ,b))]
       [`(array-sum (- ,a ,b)) `(- (array-sum ,a) (array-sum ,b))]
       [`(array-sum (scale ,s ,v)) `(* ,s (array-sum ,v))]
       [`(* (scale ,s ,u) ,v) #:when (vexprish? v) `(scale ,s (* ,u ,v))]
       [`(* ,u (scale ,s ,v)) #:when (vexprish? u) `(scale ,s (* ,u ,v))]
       [`(* (- ,a ,b) ,v) #:when (vexprish? v) `(- (* ,a ,v) (* ,b ,v))]
       [`(* ,u (- ,a ,b)) #:when (vexprish? u) `(- (* ,u ,a) (* ,u ,b))]
       [`(* (+ ,a ,b) ,v) #:when (vexprish? v) `(+ (* ,a ,v) (* ,b ,v))]
       [`(* ,u (+ ,a ,b)) #:when (vexprish? u) `(+ (* ,u ,a) (* ,u ,b))]
       [_ x]))
   e))

;; What keeps the product rules off scalar arithmetic: the other factor
;; must be recognizably a vector -- a view, a scale, or arithmetic on
;; such.  A bare symbol is not enough to tell, so bare-symbol products
;; are left alone; the fold shapes the derivation makes always carry a
;; view on at least one side.
(define (vexprish? e)
  (match e
    [`(,(or 'slice 'row 'sub 'scale) ,_ ...) #t]
    [`(,(or '+ '- '*) ,a ,b) (or (vexprish? a) (vexprish? b))]
    [_ #f]))

(define (normalize-fold e)
  (let loop ([e e] [fuel 200])
    (let ([e2 (norm-step e)])
      (if (or (equal? e2 e) (zero? fuel)) e2 (loop e2 (sub1 fuel))))))

;; ---------------- the numeric licence ----------------

;; Direct evaluation of the algebra subset on Racket vectors, enough to
;; compare a fold against its normalized form on concrete data.
(define (veval e env)
  (define (ref v) (cond [(assq v env) => cdr] [else v]))
  (match e
    [(? number?) e]
    [(? symbol?) (ref e)]
    [`(slice ,v ,lo ,hi)
     (let ([x (veval v env)] [l (veval lo env)] [h (veval hi env)])
       (for/vector ([k (in-range l h)]) (vector-ref x k)))]
    [`(scale ,s ,v)
     (let ([a (veval s env)] [x (veval v env)])
       (vector-map (lambda (t) (* a t)) x))]
    [`(array-sum ,v) (for/sum ([t (veval v env)]) t)]
    [`(vector-ref ,v ,i) (vector-ref (veval v env) (veval i env))]
    [`(,(and op (or '+ '- '* '/)) ,a ,b)
     (let ([x (veval a env)] [y (veval b env)]
           [f (case op [(+) +] [(-) -] [(*) *] [(/) /])])
       (if (and (vector? x) (vector? y))
           (vector-map f x y)
           (f x y)))]))

;; The self-test: a two-column moving-average design over a concrete
;; prefix-sum vector; the naive dot of two rows against the inlined,
;; normalized fold.  Exact over the reals, reassociated in floating
;; point, so the comparison carries a tolerance.
(define normalize-usable?
  (delay
    (with-handlers ([(lambda _ #t) (lambda _ #f)])
      (let* ([ps #(0.0 1.0 3.0 4.0 8.0 9.0 13.0 15.0)]
             [wmax 3] [nobs 4]
             [elem `(/ (- (vector-ref ps (+ ,wmax i))
                          (vector-ref ps (- (+ ,wmax i) (+ w 1))))
                       (* 1.0 (+ w 1)))]
             [defs (list (list 'xd '(w i) (list 4 nobs) elem))]
             [naive
              (lambda (j k)
                (for/sum ([i (in-range nobs)])
                  (* (veval (subst 'i i (subst 'w j elem))
                            `((ps . ,ps)))
                     (veval (subst 'i i (subst 'w k elem))
                            `((ps . ,ps))))))]
             ;; the licence must not force itself: build the normalized
             ;; form from the parts, not through the gated entry point
             [inl (inline-defs
                   '(array-sum (* (row xd j) (row xd k))) defs)]
             [norm (and inl (normalize-fold inl))])
        (and norm
             (for*/and ([j (in-range 3)] [k (in-range 3)])
               (let ([a (naive j k)]
                     [b (veval norm `((ps . ,ps) (j . ,j) (k . ,k)))])
                 (< (abs (- a b)) (* 1e-9 (max 1.0 (abs a)))))))))))

;; The entry point: inline what the definitions cover, distribute, and
;; only under the licence.  #f refuses -- unknown read shapes, a row
;; that cannot become a view, or a failed self-test.
(define (inline-normalize expr defs)
  (let ([inlined (inline-defs (inline-bare expr defs) defs)])
    (and inlined
         (let ([out (normalize-fold inlined)])
           (and (or (equal? expr out) (force normalize-usable?))
                out)))))

#lang racket
;;;; Two generic improvement rules, factored out of the derivation in
;;;; rewrite-incremental.scm so they can fire anywhere, not only on the
;;;; expression that finite differencing happens to create.
;;;;
;;;; Rule 1, precompute-const: a pure fold evaluated inside a loop, whose
;;;; free variables are all either loop coordinates or untouched by the
;;;; loop, computes the same table of values on every encounter.  Hoist
;;;; it: build the table once, indexed by the coordinates it actually
;;;; uses, and replace every occurrence by a read.  The Gram matrix of
;;;; the covariance-update lasso is one instance -- the const expression
;;;; (array-sum (* (row x k) (row x j))) that finite differencing puts
;;;; into the memo update -- but nothing here knows that; the rule hoists
;;;; any const fold.
;;;;
;;;; Rule 2, table-subset-plan / apply-table-merge: two precomputed
;;;; tables where one's defining expression is an instance of the
;;;; other's at restricted indices are one table.  The classic case is
;;;; the column norms against the Gram matrix: xnorm[j] = x_j . x_j is
;;;; G[j,j], so every read of xnorm can become a diagonal read of G and
;;;; the smaller table need never be built.  Detection is by index
;;;; substitution: a map from the big table's index variables onto the
;;;; small one's that sends one defining expression to the other.
;;;;
;;;; Both rules are cost-gated by construction rather than by a separate
;;;; check: rule 1 only fires on expressions containing a fold, so one
;;;; O(extent) reduction per visit becomes one read; rule 2 only ever
;;;; deletes a table.  Under the fixpoint driver (see the design note)
;;;; these two alternate with normalization until nothing fires.

(require (only-in (file "rewrite-incremental.scm")
                  walk-collect written-vars coordinate-vars bound-vars
                  free-symbols coordinate-extent pure? pure-heads subst))

(provide precompute-const const-candidates
         table-subset-plan apply-table-merge
         dead-fill-plan)

;; ---------------- rule 1: hoisting const folds ----------------

(define fold-heads '(array-sum array-dot array-reduce))

(define (has-fold? e)
  (pair? (walk-collect
          (lambda (x) (and (pair? x) (memq (car x) fold-heads)))
          e)))

;; A fold is not the only thing worth a table: an expensive scalar
;; operation re-evaluated across an outer loop trades tens of cycles
;; for one load, and caching it returns the identical bits -- no
;; reassociation is involved.  The redundancy gate still applies, so
;; a division evaluated once per table entry is left alone.
(define expensive-heads '(/ sqrt))

(define (has-expensive? e)
  (pair? (walk-collect
          (lambda (x) (and (pair? x) (memq (car x) expensive-heads)))
          e)))

;; range-for binders in nesting order, outermost first: the table's
;; axes keep the loop order so the build nest reads naturally.
(define (loop-coord-order e)
  (match e
    [`(range-for (,(? symbol? i) ,_ ...) ,body ...)
     (cons i (append-map loop-coord-order body))]
    [(? list?) (append-map loop-coord-order e)]
    [_ '()]))

;; A subexpression may be precomputed when it is a pure fold and every
;; variable in it is either a loop coordinate with a discoverable
;; extent (a table axis) or a variable the loop never writes.  A
;; let-bound scalar rebound each iteration admits nothing: it is
;; neither const nor an axis.
(define (const-admissible? e loop written bound coords)
  (and (pair? e) (pure? e) (or (has-fold? e) (has-expensive? e))
       (let ([vars (filter (lambda (s) (not (set-member? pure-heads s)))
                           (set->list (free-symbols e)))])
         (for/and ([v vars])
           (if (set-member? coords v)
               (let ([ext (coordinate-extent loop v)])
                 (and ext
                      (for/and ([s (set->list (free-symbols ext))])
                        (not (set-member? written s)))))
               (and (not (set-member? written v))
                    (not (set-member? bound v))))))))

;; Maximal admissible subtrees: take a node whole when it qualifies,
;; descend otherwise.  Growth-by-maximality mirrors the context search
;; of the differencing pass, with const-ness in place of linearity.
;;
;; The cost gate rides along: a candidate only counts when some
;; enclosing loop coordinate is not one of its own axes, so the fold
;; really is re-evaluated across iterations the table would absorb.
;; Without it the rule re-hoists every table build it just emitted --
;; the build loop's fold has exactly its own coordinates -- and the
;; driver would never stop.
(define (const-candidates loop)
  (define written (written-vars loop))
  (define bound (bound-vars loop))
  (define coords (coordinate-vars loop))
  (define (redundant? e outer)
    (let ([fv (free-symbols e)])
      (ormap (lambda (o) (not (set-member? fv o))) outer)))
  (define (go e outer)
    (if (and (const-admissible? e loop written bound coords)
             (redundant? e outer))
        (list e)
        (match e
          [`(range-for (,(? symbol? i) ,_ ...) ,body ...)
           (append-map (lambda (b) (go b (cons i outer))) body)]
          [(? list?) (append-map (lambda (b) (go b outer)) e)]
          [_ '()])))
  (remove-duplicates (go loop '())))

;; Hoist every candidate: scalars (no coordinate) become let bindings,
;; the rest become tables built by one loop nest per axis.  Returns #f
;; when nothing qualifies, else the rewritten block.
(define (precompute-const loop)
  (define coords (coordinate-vars loop))
  ;; one axis per coordinate name: emitted code reuses binder symbols
  ;; across sibling loops, and a duplicated axis would square or cube
  ;; the table while only its diagonal is ever touched
  (define order (remove-duplicates (loop-coord-order loop)))
  (define cands (const-candidates loop))
  (define (axes-of c)
    (filter (lambda (i) (set-member? (free-symbols c) i)) order))
  (and (pair? cands)
       (let* ([infos (for/list ([c cands])
                       (let ([axes (axes-of c)])
                         (list c (gensym 'pc) axes
                               (for/list ([i axes])
                                 (coordinate-extent loop i)))))]
              [scalars (filter (lambda (i) (null? (caddr i))) infos)]
              [tables  (filter (lambda (i) (pair? (caddr i))) infos)]
              [loop2
               (for/fold ([e loop]) ([i infos])
                 (match-define (list c t axes _) i)
                 (subst c (if (null? axes) t `(array-ref ,t ,@axes)) e))]
              [builds
               (for/list ([i tables])
                 (match-define (list c t axes exts) i)
                 ;; the build binders reuse the coordinate names, so the
                 ;; candidate expression needs no substitution at all
                 (for/fold ([body `(array-set! ,t ,@axes ,c)])
                           ([a (reverse axes)] [x (reverse exts)])
                   `(range-for (,a ,x) ,body)))]
              [body (if (null? tables)
                        `(,loop2)
                        `((with-arrays
                           ,(for/list ([i tables])
                              (list (cadr i) (cadddr i)))
                           ,@builds
                           ,loop2
                           0)))])
         `(let (,@(for/list ([i scalars]) (list (cadr i) (car i)))
                ,@(for/list ([i tables])
                    (match-define (list _ t _ exts) i)
                    `(,t (make-vector (* ,@exts) 0.0))))
            ,@body))))

;; ---------------- rule 2: merging subset tables ----------------

;; defs: one entry per precomputed table, (name (index ...) expr), the
;; expression written in the entry's own index variables.

(define (index-maps big-idx small-idx)
  (if (null? big-idx)
      '(())
      (for*/list ([m (index-maps (cdr big-idx) small-idx)]
                  [s small-idx])
        (cons (cons (car big-idx) s) m))))

;; For each table whose definition is an instance of a larger table's
;; definition at restricted indices, the plan records which table
;; absorbs it and by which index map.  (xnorm (j) x_j.x_j) against
;; (g (k1 k2) x_k1.x_k2) yields ((xnorm g ((k1 . j) (k2 . j)))).
(define (table-subset-plan defs)
  (define absorbed
    (filter values
            (for/list ([small defs])
              (match-define (list sn sidx sexpr) small)
              (for/or ([big defs])
                (match-define (list bn bidx bexpr) big)
                (and (not (eq? sn bn))
                     (>= (length bidx) (length sidx))
                     (for/or ([sig (index-maps bidx sidx)])
                       (and (for/and ([s sidx]) (memq s (map cdr sig)))
                            (equal? sexpr
                                    (for/fold ([e bexpr]) ([p sig])
                                      (subst (car p) (cdr p) e)))
                            (list sn bn sig))))))))
  ;; a table that absorbs another may not itself be merged away: the
  ;; read rewrite targets it by name
  (let ([bigs (map cadr absorbed)])
    (filter (lambda (m) (not (memq (car m) bigs))) absorbed)))

(define (tree-map f e)
  (f (if (list? e) (map (lambda (x) (tree-map f x)) e) e)))

;; Rewrite every read of a merged table into the read of its absorber:
;; the index map, inverted positionally, says which of the small read's
;; index expressions feeds each axis of the big table.
(define (apply-table-merge e plan defs)
  (for/fold ([e e]) ([m plan])
    (match-define (list sn bn sig) m)
    (define sidx (cadr (assq sn defs)))
    (define bidx (cadr (assq bn defs)))
    (tree-map
     (lambda (x)
       (match x
         [`(,(or 'vector-ref 'array-ref) ,(== sn) ,as ...)
          #:when (= (length as) (length sidx))
          `(array-ref ,bn
                      ,@(for/list ([b bidx])
                          (list-ref as (index-of sidx (cdr (assq b sig))))))]
         [_ x]))
     e)))

;; ---------------- rule: dropping dead fills ----------------

;; A fill statement for a: a pure loop nest whose single statement
;; writes a, in the two shapes the layer's fills take.  Purity
;; matters: a fill whose element expression carries a side effect is
;; not removable however unread its target is.
(define (fill-stmt-for? s a)
  (let loop ([s s] [depth 0])
    (match s
      [`(range-for (,_ ,_) ,inner) (loop inner (add1 depth))]
      [`(,(or 'vector-set! 'array-set!) ,(? symbol? x) ,r ...)
       (and (> depth 0) (eq? x a) (andmap pure? r))]
      [_ #f])))

;; Arrays every occurrence of which sits inside one of their own pure
;; fill statements: nothing reads what the fill wrote, so the fill
;; was the array's only effect and can go.  Dropping one fill can
;; orphan the arrays it read, so callers re-plan until nothing dies
;; -- the driver's rounds do exactly that.  live-out names are
;; observable after the statement list -- outputs -- and are never
;; candidates: their fills ARE the effect.
(define (dead-fill-plan stmts live-out)
  ;; a binder position is not a read: the array's name in a let
  ;; binding or a with-arrays declaration says where it lives, not
  ;; that anyone looks at it.  Initializer and extent expressions are
  ;; still walked.
  (define (occurs-outside? a)
    (let go ([e stmts])
      (cond [(fill-stmt-for? e a) #f]
            [(eq? e a) #t]
            [(and (pair? e) (memq (car e) '(let with-arrays))
                  (pair? (cdr e)) (list? (cadr e))
                  (andmap pair? (cadr e)))
             (or (for/or ([b (cadr e)]) (go (cdr b)))
                 (go (cddr e)))]
            [(pair? e) (or (go (car e)) (go (cdr e)))]
            [else #f])))
  (define targets
    (remove-duplicates
     (filter values
             (for/list ([s (walk-collect pair? stmts)])
               (match s
                 [`(,(or 'vector-set! 'array-set!) ,(? symbol? x) ,_ ...) x]
                 [_ #f])))))
  (filter (lambda (a)
            (and (not (memq a live-out))
                 (for/or ([s (walk-collect pair? stmts)])
                   (fill-stmt-for? s a))
                 (not (occurs-outside? a))))
          targets))

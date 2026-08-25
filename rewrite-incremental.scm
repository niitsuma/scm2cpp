#lang racket
;;;; Finite differencing over the array algebra: derive the covariance
;;;; update instead of pattern-matching for it.
;;;;
;;;; The first version of this module recognised one fixed read shape,
;;;; (array-sum (* (row X k) v)). This one derives the shape: starting
;;;; from each occurrence of the scratch vector v, the enclosing
;;;; expression is GROWN outward for as long as three conditions hold,
;;;; and the maximal admissible block is the context to memoise.
;;;;
;;;;   pure       the block performs no writes;
;;;;   linear     the block has degree exactly one in v, so it commutes
;;;;              with an affine update: C[v - d*u] = C[v] - d*C[u];
;;;;   invariant  every other free variable is either untouched by the
;;;;              sweep, or is one loop coordinate -- which becomes the
;;;;              memo's index.
;;;;
;;;; Growth stops by itself exactly where it should. It cannot swallow
;;;; (* old (vector-ref xnorm j)) because old is rebound every
;;;; iteration; it refuses (array-sum (* v v)) because the degree is
;;;; two; it happily passes through an invariant coefficient, so
;;;; (* 0.5 (array-sum (* (row x j) v))) memoises whole. Nothing here
;;;; matches for a dot product -- the dot is just what growth finds in
;;;; the lasso kernel.
;;;;
;;;; Contexts are then grouped into families by replacing their one
;;;; coordinate with a hole; each family gets its own memo vector c,
;;;; initialised from the context itself, read where the context stood,
;;;; and maintained through each update by the pushed-through kernel
;;;; C_k[u_j] -- which is v-free, hoists out of the sweeps, and for the
;;;; lasso context IS the Gram matrix. v is restored once at the end
;;;; from the coefficients' total movement; under a scratch verdict
;;;; from the liveness pass the caller may drop that one loop.

(provide incrementalize degree
         ;; analysis helpers, shared with rewrite-precompute.scm
         walk-collect written-vars coordinate-vars bound-vars
         free-symbols coordinate-extent pure? pure-heads subst)

;; ---------------- facts about the sweep ----------------

(define (walk-collect f e)
  (let loop ([e e] [acc '()])
    (let ([acc (if (f e) (cons e acc) acc)])
      (if (pair? e)
          (loop (cdr e) (loop (car e) acc))
          acc))))

;; Variables the sweep writes: targets of set! and of the array forms.
(define (written-vars sweep)
  (for/fold ([s (seteq)])
            ([e (walk-collect pair? sweep)])
    (match e
      [`(set! ,(? symbol? x) ,_) (set-add s x)]
      [`(,(or 'vector-set! 'array-set! 'array-inc! 'array-dec!)
         ,(? symbol? x) ,_ ...) (set-add s x)]
      [_ s])))

;; Loop coordinates: variables bound by a range-for. Only these may
;; appear free in a context -- they become memo axes. A let-bound
;; scalar like old is rebound every iteration and can index nothing.
(define (coordinate-vars sweep)
  (for/fold ([s (seteq)])
            ([e (walk-collect pair? sweep)])
    (match e
      [`(range-for (,(? symbol? i) ,_ ...) ,_ ...) (set-add s i)]
      [_ s])))

;; Variables bound inside the sweep, by range-for or let.
(define (bound-vars sweep)
  (for/fold ([s (seteq)])
            ([e (walk-collect pair? sweep)])
    (match e
      [`(range-for (,(? symbol? i) ,_ ...) ,_ ...) (set-add s i)]
      [`(range-fold ((,(? symbol? a) ,_) (,(? symbol? i) ,_)) ,_)
       (set-add (set-add s a) i)]
      [`(let ,(? list? bs) ,_ ...)
       (for/fold ([s s]) ([b bs])
         (if (and (pair? b) (symbol? (car b))) (set-add s (car b)) s))]
      [_ s])))

(define (free-symbols e)
  (for/fold ([s (seteq)])
            ([x (walk-collect symbol? e)])
    (set-add s x)))

;; The extent of a coordinate: the (range-for (h P) ...) that binds it.
(define (coordinate-extent sweep h)
  (for/or ([e (walk-collect pair? sweep)])
    (match e
      [`(range-for (,(== h) ,P) ,_ ...) P]
      [_ #f])))

;; ---------------- the three conditions ----------------

(define pure-heads
  (seteq '+ '- '* '/ 'vector-ref 'array-ref 'array-sum 'array-dot
         'array-reduce 'sub 'slice
         'row 'scale 'range-sum 'min 'max 'abs 'sqrt))

(define (pure? e)
  (cond [(or (symbol? e) (number? e)) #t]
        [(pair? e) (and (symbol? (car e))
                        (set-member? pure-heads (car e))
                        (andmap pure? (cdr e)))]
        [else #f]))

;; Degree of E in V: 0, 1, or 'nl. Sums keep the max; a product may
;; carry at most one degree-one factor; scale demands a scalar left.
(define (degree e v)
  (define (max* a b)
    (cond [(or (eq? a 'nl) (eq? b 'nl)) 'nl] [else (max a b)]))
  (cond
    [(eq? e v) 1]
    [(symbol? e) 0]
    [(number? e) 0]
    [(pair? e)
     (match e
       [`(,(or '+ '-) ,es ...)
        (for/fold ([d 0]) ([x es]) (max* d (degree x v)))]
       [`(* ,es ...)
        (let ([ds (map (lambda (x) (degree x v)) es)])
          (cond [(ormap (lambda (d) (eq? d 'nl)) ds) 'nl]
                [(> (length (filter (lambda (d) (= d 1)) ds)) 1) 'nl]
                [(ormap (lambda (d) (= d 1)) ds) 1]
                [else 0]))]
       ;; scale is a product: linear when at most one side carries the
       ;; degree, whichever side that is -- a v-dependent scalar times a
       ;; constant vector is as linear as the mirror case
       [`(scale ,c ,u)
        (degree `(* ,c ,u) v)]
       [`(,(or 'array-sum 'range-sum) ,_ ... ,body) (degree body v)]
       ;; a reduction is linear in v only under the additive monoid;
       ;; a product or a max of v-dependent terms does not push through
       [`(array-reduce ,op ,id ,body)
        (cond [(not (eqv? 0 (degree id v))) 'nl]
              [(eq? op '+) (degree body v)]
              [(eqv? 0 (degree body v)) 0]
              [else 'nl])]
       [`(array-dot ,a ,b) (degree `(* ,a ,b) v)]
       ;; tensor ACCESS is linear in the tensor: a row of v, or an
       ;; element of v, is a linear function of v -- it is composition
       ;; with a projection, and projections are linear. The indices
       ;; must not involve v: v[v[0]] is not multilinear in v.
       [`(row ,a ,i)
        (cond [(not (eqv? 0 (degree i v))) 'nl]
              [(eq? a v) 1]
              [else 0])]
       ;; a slice is a projection composed with the view it slices, a
       ;; sub-box read is a family of projections: both linear, indices
       ;; permitting
       [`(slice ,u ,ixs ...)
        (if (andmap (lambda (i) (eqv? 0 (degree i v))) ixs)
            (degree u v) 'nl)]
       [`(sub ,a ,ixs ...)
        (cond [(not (andmap (lambda (i) (eqv? 0 (degree i v))) ixs)) 'nl]
              [(eq? a v) 1]
              [else 0])]
       [`(vector-ref ,a ,i)
        (cond [(not (eqv? 0 (degree i v))) 'nl]
              [(eq? a v) 1]
              [else (degree a v)])]
       [`(array-ref ,a ,is ...)
        (cond [(not (andmap (lambda (i) (eqv? 0 (degree i v))) is)) 'nl]
              [(eq? a v) 1]
              [else (degree a v)])]
       [_ (if (set-member? (free-symbols e) v) 'nl 0)])]
    [else 0]))

;; ---------------- growth ----------------

;; A block is admissible as a context when it is pure, degree one in v,
;; and its free variables besides v are invariant except for at most one
;; loop coordinate.
(define (admissible? e v written bound coords)
  (and (pair? e)                ; the bare v is the identity context:
                                ; memoising it is copying, and it would
                                ; double-claim occurrences a catalog
                                ; entry owns
       (pure? e)
       (eqv? 1 (degree e v))
       (let* ([fs (set-remove (free-symbols e) v)]
              [bs (set->list (set-intersect fs bound))]
              [ws (set->list (set-intersect fs written))])
         ;; up to two coordinates -- the sweep's, and for a matrix
         ;; scratch the row coordinate of its access -- and every bound
         ;; variable must BE a coordinate: a let-bound scalar (old) is
         ;; rebound each iteration and stops the growth just below it
         (and (<= (length bs) 2)
              (andmap (lambda (b) (set-member? coords b)) bs)
              (null? ws)))))

;; Maximal admissible blocks: admissible, containing v, with no
;; admissible ancestor. Update sites are skipped -- they are v's writes.
(define (maximal-contexts sweep v written bound coords)
  (define out '())
  (define (go e covered)
    (match e
      [`(array-dec! ,(== v) ,_) (void)]        ; an update, handled apart
      [`(row-dec! ,(== v) ,_ ,_) (void)]       ; likewise, the row shape
      [_
       (let ([adm (and (not covered) (admissible? e v written bound coords))])
         (when adm (set! out (cons e out)))
         (when (pair? e)
           (for ([sub (if (and (pair? e) (eq? (car e) 'quote)) '() e)])
             (go sub (or covered adm)))))]))
  (go sweep #f)
  (reverse out))

;; ---------------- the homomorphism catalog ----------------
;;
;; Linearity is the syntactic sufficient condition for a conjugate
;; update; it is not the boundary. A context that is NOT linear may
;; still commute with the affine update through a known identity, and
;; such identities live here as catalog entries: a shape, the conjugate
;; it licenses, and a numeric self-test of the identity itself, run
;; once before the entry may fire -- the same philosophy as the rewrite
;; rules' self-test gate, in miniature.
;;
;; One entry so far: the squared norm. ||v - d u||^2 expands to
;; ||v||^2 - 2 d (u.v) + d^2 (u.u), so a memoised ||v||^2 is maintained
;; from the dot memo the linear machinery already keeps and the Gram
;; diagonal already hoisted -- the quadratic rides on the linear.

(define (sq-norm-identity-holds?)
  (let* ([v (vector 3.0 1.0 2.0 0.0)] [u (vector 1.0 -1.0 1.0 -1.0)]
         [d 0.25]
         [dot (lambda (a b) (for/sum ([x a] [y b]) (* x y)))]
         [v2 (for/vector ([x v] [y u]) (- x (* d y)))]
         [lhs (dot v2 v2)]
         [rhs (+ (dot v v) (* -2.0 d (dot u v)) (* d d (dot u u)))])
    (< (abs (- lhs rhs)) 1e-12)))

(define sq-norm-usable? (delay (sq-norm-identity-holds?)))

;; ---------------- the derivation ----------------

(define (subst what for e)
  (cond [(equal? e what) for]
        [(pair? e) (cons (subst what for (car e)) (subst what for (cdr e)))]
        [else e]))

(define (swap-syms e a b)
  (subst '%%swap%% b (subst b a (subst a '%%swap%% e))))

;; Equality modulo commutativity of + and *: what makes the Gram
;; kernel's symmetry provable from its defining expression alone.
(define (comm-equal? a b)
  (or (equal? a b)
      (and (pair? a) (pair? b)
           (or (and (memq (car a) '(+ *)) (eq? (car a) (car b))
                    (= 3 (length a)) (= 3 (length b))
                    (comm-equal? (cadr a) (caddr b))
                    (comm-equal? (caddr a) (cadr b)))
               (and (comm-equal? (car a) (car b))
                    (comm-equal? (cdr a) (cdr b)))))))

(define (incrementalize sweep v beta #:restore? [restore? #t])
  (define written (written-vars sweep))
  (define bound (bound-vars sweep))
  (define coords (coordinate-vars sweep))
  (define ctxs (maximal-contexts sweep v written bound coords))
  ;; updates come in two shapes: the whole-vector decrement, and its
  ;; matrix counterpart that touches one row -- v <- v - e_t (x) (d u).
  ;; Each is (site kind d x j t), t being #f for the vector shape.
  (define updates
    (filter values
            (for/list ([e (walk-collect pair? sweep)])
              (match e
                [`(array-dec! ,(== v) (scale ,d (row ,x ,j)))
                 (and (symbol? x) (symbol? j)
                      (not (set-member? written x))
                      (list e 'vec d x j #f))]
                [`(row-dec! ,(== v) ,(? symbol? t) (scale ,d (row ,x ,j)))
                 (and (symbol? x) (symbol? j)
                      (not (set-member? written x))
                      (list e 'row d x j t))]
                [_ #f]))))
  ;; catalog sites: squared-norm reads of v, licensed by the identity's
  ;; own self-test and only for the vector update shape
  (define sq-sites
    (if (force sq-norm-usable?)
        (remove-duplicates
         (walk-collect
          (lambda (e) (match e
                        [`(array-sum (* ,(== v) ,(== v))) #t]
                        [_ #f]))
          sweep))
        '()))
  (define v-occurrences
    (length (walk-collect (lambda (e) (eq? e v)) sweep)))
  (define accounted
    (+ (for/sum ([c ctxs]) (length (walk-collect (lambda (e) (eq? e v)) c)))
       (* 2 (length sq-sites))
       (length updates)))
  ;; how v is read inside a context: the minimal access subtree -- bare v
  ;; for a vector, (row v t) for a matrix read. The kernel substitution
  ;; replaces exactly this subtree by the update's direction.
  (define (v-access c)
    (or (for/or ([e (walk-collect pair? c)])
          (match e [`(row ,(== v) ,(? symbol? _)) e] [_ #f]))
        v))
  (when (getenv "INC_DEBUG")
    (eprintf "ctxs=~s sq=~s occ=~a acc=~a upd=~a\n"
             ctxs sq-sites v-occurrences accounted (length updates)))
  (and
   (pair? ctxs) (pair? updates)
   (= v-occurrences accounted)
   ;; kinds may not mix, and the matrix shape has no restoration yet:
   ;; it is only derivable under a scratch verdict
   (let ([kinds (remove-duplicates (map cadr updates))])
     (and (= 1 (length kinds))
          (or (eq? (car kinds) 'vec) (not restore?))
          (or (null? sq-sites) (eq? (car kinds) 'vec))))
   ;; each context names one coordinate per axis of the memo: the sweep
   ;; coordinate always, and for a matrix scratch the row coordinate of
   ;; its access. Hole them in order of appearance, group families.
   (let* ([jset (remove-duplicates (map (lambda (u) (list-ref u 4)) updates))]
          [holed
           (for/list ([c ctxs])
             (let* ([hs0 (filter (lambda (x) (set-member? bound x))
                                 (remove-duplicates (walk-collect symbol? c)))]
                    ;; the sweep coordinate goes last, whatever the
                    ;; traversal met first: hole numbering, memo axes and
                    ;; the P computation below all key on that position
                    [hs (append (filter (lambda (h) (not (memq h jset))) hs0)
                                (filter (lambda (h) (memq h jset)) hs0))])
               (and (<= 1 (length hs) 2)
                    (list (for/fold ([e c]) ([h hs] [k (in-naturals)])
                            (subst h (string->symbol (format "?H~a" k)) e))
                          hs c))))]
          [families (remove-duplicates (map car (filter values holed)))])
     (and (andmap values holed)
          ;; every family agrees on its coordinate list's extents, and
          ;; the last coordinate is the sweep coordinate of the updates
          (let* ([hvars (remove-duplicates (append-map cadr (filter values holed)))]
                 [jvars (remove-duplicates (map (lambda (u) (list-ref u 4)) updates))]
                 [P (let ([es (remove-duplicates
                               (filter values
                                       (map (lambda (x) (coordinate-extent sweep x))
                                            (append (list (car (reverse (cadr (car (filter values holed)))))) jvars))))])
                      (and (= 1 (length es)) (car es)))])
            (and P
                 (let* ([fam-holes    ; per family: its ordered hole vars
                         (for/list ([fam families])
                           (cadr (for/or ([hc (filter values holed)])
                                   (and (equal? (car hc) fam) hc))))]
                        [fam-extents
                         (for/list ([hs fam-holes])
                           (for/list ([h hs]) (coordinate-extent sweep h)))]
                        [_ok (andmap (lambda (es) (andmap values es)) fam-extents)]
                        [cs (for/list ([_ families]) (gensym 'c))]
                        [gs (for/list ([_ families]) (gensym 'g))]
                        [b0 (gensym 'b0)] [k1 (gensym 'k)] [k2 (gensym 'k)]
                        [jj (gensym 'j)]
                        [decls (append
                                (for/list ([g gs]) `(,g (,P ,P)))
                                (for/list ([c cs] [es fam-extents]) `(,c ,es)))]
                        ;; rewrite the sweep: reads become memo reads,
                        ;; updates maintain every family's memo
                        ;; the squared norm rides on the dot family of
                        ;; the update's own matrix: find it, or refuse
                        [dot-fam-index
                         (and (pair? sq-sites)
                              (let ([x (list-ref (car updates) 3)])
                                (index-of families
                                          `(array-sum (* (row ,x ?H0) ,v)))))]
                        [sq (and (pair? sq-sites) (gensym 'sq))]
                        ;; G_f[k1,k2] = G_f[k2,k1] whenever the emitted
                        ;; element is fixed by swapping its two hole
                        ;; coordinates, up to commutativity of the
                        ;; product -- true for any dot-shaped context.
                        ;; A symmetric kernel lets the memo update read
                        ;; the row instead of the column: the same
                        ;; values (multiplication commutes bitwise) laid
                        ;; out sequentially, which is what keeps the
                        ;; sweep from thrashing once G outgrows cache.
                        [g-symmetric?
                         (for/list ([fam families] [hs fam-holes])
                           (let* ([x (list-ref (car updates) 3)]
                                  [sh (string->symbol
                                       (format "?H~a" (sub1 (length hs))))]
                                  [e12 (subst sh '%K1
                                              (subst (v-access fam)
                                                     `(row ,x %K2) fam))])
                             (comm-equal? e12 (swap-syms e12 '%K1 '%K2))))]
                        [sweep2
                         (for/fold ([e sweep])
                                   ([hc (filter values holed)])
                           (match-define (list fam hs orig) hc)
                           (define ci (list-ref cs (index-of families fam)))
                           (subst orig `(array-ref ,ci ,@hs) e))]
                        [sweep2b
                         (if sq
                             (for/fold ([e sweep2]) ([site sq-sites])
                               (subst site `(vector-ref ,sq 0) e))
                             sweep2)]
                        [sweep3
                         (for/fold ([e sweep2b])
                                   ([u updates])
                           (match-define (list site kind d x j t) u)
                           (subst site
                                  `(begin
                                     ;; the quadratic memo first: it reads
                                     ;; the dot memo BEFORE its own update
                                     ,@(if sq
                                           (let ([cd (list-ref cs dot-fam-index)]
                                                 [gd (list-ref gs dot-fam-index)])
                                             (list
                                              `(vector-set! ,sq 0
                                                 (+ (vector-ref ,sq 0)
                                                    (+ (* (* -2.0 ,d)
                                                          (array-ref ,cd ,j))
                                                       (* (* ,d ,d)
                                                          (array-ref ,gd ,j ,j)))))))
                                           '())
                                     ,@(for/list ([ci cs] [gi gs] [hs fam-holes]
                                                  [sym g-symmetric?])
                                         ;; a row update touches only the
                                         ;; slice at its own row coordinate;
                                         ;; the sweep coordinate ranges
                                         `(range-for (,k2 ,P)
                                            (array-dec! ,ci
                                                        ,@(for/list ([h hs])
                                                            (if (eq? h t) t
                                                                k2))
                                                        (* (array-ref ,gi
                                                                      ,@(if sym
                                                                            (list j k2)
                                                                            (list k2 j)))
                                                           ,d)))))
                                  e))])
                   (and _ok
                        (or (null? sq-sites) dot-fam-index)
                   `(let (,@(if sq `((,sq (make-vector 1 0.0))) '())
                          (,b0 (make-vector ,P 0.0))
                          ,@(for/list ([g gs]) `(,g (make-vector (* ,P ,P) 0.0)))
                          ,@(for/list ([c cs] [es fam-extents])
                              `(,c (make-vector (* ,@es) 0.0))))
                      (with-arrays ,decls
                        ;; hoisted kernels: G_f[k1,k2] = C_f applied to the
                        ;; update's direction at k2, sweep hole at k1 --
                        ;; the v access, row or whole, becomes the
                        ;; direction, so G never mentions v
                        ,@(for/list ([fam families] [g gs] [hs fam-holes])
                            (match-define (list _ kind d x j t) (car updates))
                            (define sweep-hole
                              (string->symbol (format "?H~a" (sub1 (length hs)))))
                            `(range-for (,k1 ,P)
                               (range-for (,k2 ,P)
                                 (array-set! ,g ,k1 ,k2
                                             ,(subst sweep-hole k1
                                                     (subst (v-access fam)
                                                            `(row ,x ,k2) fam))))))
                        ;; memos: c_f[h..] = C_f,h.. [ v ], one loop per axis
                        ,@(for/list ([fam families] [c cs]
                                     [hs fam-holes] [es fam-extents])
                            (let ([ks (for/list ([_ hs]) (gensym 'k))])
                              (for/fold ([body `(array-set! ,c ,@ks
                                                 ,(for/fold ([e fam])
                                                            ([h (in-naturals)] [k ks])
                                                    (subst (string->symbol
                                                            (format "?H~a" h))
                                                           k e)))])
                                        ([k (reverse ks)] [e (reverse es)])
                                `(range-for (,k ,e) ,body))))
                        (range-for (,k1 ,P)
                          (vector-set! ,b0 ,k1 (vector-ref ,beta ,k1)))
                        ,@(if sq
                              (list `(vector-set! ,sq 0
                                       (array-sum (* ,v ,v))))
                              '())
                        ,sweep3
                        ;; restoration: emitted only when someone can see
                        ;; v afterwards; the liveness pass's scratch
                        ;; verdict is the licence to omit it
                        ,@(if restore?
                              (let ([x (list-ref (car updates) 3)])
                                (list
                                 `(range-for (,jj ,P)
                                    (array-dec! ,v
                                                (scale (- (vector-ref ,beta ,jj)
                                                          (vector-ref ,b0 ,jj))
                                                       (row ,x ,jj))))))
                              '())
                        0))))))))))

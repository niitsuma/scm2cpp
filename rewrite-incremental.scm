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

(provide incrementalize degree)

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
       [`(array-dot ,a ,b) (degree `(* ,a ,b) v)]
       ;; tensor ACCESS is linear in the tensor: a row of v, or an
       ;; element of v, is a linear function of v -- it is composition
       ;; with a projection, and projections are linear. The indices
       ;; must not involve v: v[v[0]] is not multilinear in v.
       [`(row ,a ,i)
        (cond [(not (eqv? 0 (degree i v))) 'nl]
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
(define (admissible? e v written bound)
  (and (pure? e)
       (eqv? 1 (degree e v))
       (let* ([fs (set-remove (free-symbols e) v)]
              [bs (set->list (set-intersect fs bound))]
              [ws (set->list (set-intersect fs written))])
         ;; at most one coordinate, and nothing the sweep writes: a
         ;; variable rebound every iteration (old, bnew) is not
         ;; invariant, so growth stops just below it
         (and (<= (length bs) 1)
              (null? ws)))))

;; Maximal admissible blocks: admissible, containing v, with no
;; admissible ancestor. Update sites are skipped -- they are v's writes.
(define (maximal-contexts sweep v written bound)
  (define out '())
  (define (go e covered)
    (match e
      [`(array-dec! ,(== v) ,_) (void)]        ; an update, handled apart
      [_
       (let ([adm (and (not covered) (admissible? e v written bound))])
         (when adm (set! out (cons e out)))
         (when (pair? e)
           (for ([sub (if (and (pair? e) (eq? (car e) 'quote)) '() e)])
             (go sub (or covered adm)))))]))
  (go sweep #f)
  (reverse out))

;; ---------------- the derivation ----------------

(define (subst what for e)
  (cond [(equal? e what) for]
        [(pair? e) (cons (subst what for (car e)) (subst what for (cdr e)))]
        [else e]))

(define (incrementalize sweep v beta)
  (define written (written-vars sweep))
  (define bound (bound-vars sweep))
  (define ctxs (maximal-contexts sweep v written bound))
  (define updates
    (filter values
            (for/list ([e (walk-collect pair? sweep)])
              (match e
                [`(array-dec! ,(== v) (scale ,d (row ,x ,j)))
                 (and (symbol? x) (symbol? j)
                      (not (set-member? written x))
                      (list e d x j))]
                [_ #f]))))
  (define v-occurrences
    (length (walk-collect (lambda (e) (eq? e v)) sweep)))
  (define accounted
    (+ (for/sum ([c ctxs]) (length (walk-collect (lambda (e) (eq? e v)) c)))
       (length updates)))
  (and
   (pair? ctxs) (pair? updates)
   (= v-occurrences accounted)
   ;; each context names exactly one coordinate; hole it, group families
   (let* ([holed
           (for/list ([c ctxs])
             (let ([h (set->list (set-intersect (free-symbols c) bound))])
               (and (= 1 (length h)) (list (subst (car h) '?H c) (car h) c))))]
          [_ (and (andmap values holed))]
          [families (remove-duplicates (map car (filter values holed)))])
     (and (andmap values holed)
          ;; every hole and every update coordinate share one extent
          (let* ([hvars (remove-duplicates (map cadr (filter values holed)))]
                 [jvars (remove-duplicates (map cadddr updates))]
                 [P (let ([es (remove-duplicates
                               (filter values
                                       (map (lambda (x) (coordinate-extent sweep x))
                                            (append hvars jvars))))])
                      (and (= 1 (length es)) (car es)))])
            (and P
                 (let* ([cs (for/list ([_ families]) (gensym 'c))]
                        [gs (for/list ([_ families]) (gensym 'g))]
                        [b0 (gensym 'b0)] [k1 (gensym 'k)] [k2 (gensym 'k)]
                        [jj (gensym 'j)]
                        [decls (append
                                (for/list ([g gs]) `(,g (,P ,P)))
                                (for/list ([c cs]) `(,c (,P))))]
                        ;; rewrite the sweep: reads become memo reads,
                        ;; updates maintain every family's memo
                        [sweep2
                         (for/fold ([e sweep])
                                   ([hc (filter values holed)])
                           (match-define (list fam h orig) hc)
                           (define ci (list-ref cs (index-of families fam)))
                           (subst orig `(array-ref ,ci ,h) e))]
                        [sweep3
                         (for/fold ([e sweep2])
                                   ([u updates])
                           (match-define (list site d x j) u)
                           (subst site
                                  `(begin
                                     ,@(for/list ([ci cs] [gi gs])
                                         `(range-for (,k2 ,P)
                                            (array-dec! ,ci ,k2
                                                        (* (array-ref ,gi ,k2 ,j) ,d)))))
                                  e))])
                   `(let ((,b0 (make-vector ,P 0.0))
                          ,@(for/list ([g gs]) `(,g (make-vector (* ,P ,P) 0.0)))
                          ,@(for/list ([c cs]) `(,c (make-vector ,P 0.0))))
                      (with-arrays ,decls
                        ;; hoisted kernels: G_f[k1,k2] = C_f,k1 [ u(k2) ],
                        ;; the context applied to the update's direction
                        ,@(for/list ([fam families] [g gs])
                            (match-define (list _ d x j) (car updates))
                            `(range-for (,k1 ,P)
                               (range-for (,k2 ,P)
                                 (array-set! ,g ,k1 ,k2
                                             ,(subst v `(row ,x ,k2)
                                                     (subst '?H k1 fam))))))
                        ;; memos: c_f[k1] = C_f,k1 [ v ]
                        ,@(for/list ([fam families] [c cs])
                            `(range-for (,k1 ,P)
                               (array-set! ,c ,k1 ,(subst '?H k1 fam))))
                        (range-for (,k1 ,P)
                          (vector-set! ,b0 ,k1 (vector-ref ,beta ,k1)))
                        ,sweep3
                        ;; restoration, droppable under a scratch verdict
                        ,(let ([x (caddr (car updates))])
                           `(range-for (,jj ,P)
                              (array-dec! ,v (scale (- (vector-ref ,beta ,jj)
                                                       (vector-ref ,b0 ,jj))
                                                    (row ,x ,jj)))))
                        0)))))))))

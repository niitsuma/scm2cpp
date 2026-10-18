#lang racket
;;;; Work on loop-invariant data, done once (--derive).
;;;;
;;;; Inside a loop L, an array L never writes is invariant, and an array
;;;; L fills from one by an operation that costs nothing next to what is
;;;; done with it -- an index lookup, a gather -- is quasi-invariant: it
;;;; is a function of the invariant data and of the few values that
;;;; parametrise the lookup.  Whatever expensive operation L applies to
;;;; such arrays again and again can then be applied once, and the cheap
;;;; operation applied to its result.  Two forms of that here:
;;;;
;;;; 1. Products (hoist-invariant-products).  A loop that forms, every
;;;;    time round, a product of columns gathered from an X it never
;;;;    writes --
;;;;
;;;;      (do ((i 0 (+ i 1))) ((= i n))              ; xk = X[:, idx]
;;;;        (do ((c 0 (+ c 1))) ((= c k))
;;;;          (vector-set! xk (+ (* i k) c) (vector-ref x (+ (* i p) (vector-ref idx c))))))
;;;;      (with-arrays ((xk (n k)) (gk (k k)))
;;;;        (array-set! gk (matmul (transpose xk) xk)))
;;;;
;;;;    -- computes entries of one fixed table: gk[r,c] is
;;;;    (X'X)[idx[r],idx[c]].  The table T = X'X is allocated before the
;;;;    loop and formed on its first use, as a product again (so --blas
;;;;    makes it one dsyrk or dgemm), and the product becomes the lookup
;;;;    gk[r,c] = T[idx[r], idx[c]]; the fill of xk goes when nothing else
;;;;    in the loop reads it.  At any rank: the fill is a nest of counting
;;;;    loops a[v1,..,vr] = x[u1,..,ur], every axis of x indexed either by
;;;;    one of the loop variables itself (a full axis) or by an expression
;;;;    E(v) of exactly one of them (a gathered axis) -- x[i1, e1(c1),
;;;;    e2(c2), i2, ..] -- and the product is (contract KS YS (a ..) (b ..))
;;;;    or one of the matmul forms, which are contractions.  Summed labels
;;;;    must fall on full axes (a sum over a gathered set is no table
;;;;    entry); the table carries every free label at the full extent of
;;;;    the axis it sits on, and the lookup applies E to the label of a
;;;;    gathered axis.  ard.scm's HOIST 1 is this rewrite by hand.
;;;;
;;;; 2. Calls (memo-invariant-calls).  A product that no contraction
;;;;    spells -- f(op(X, p1), p2) for a pure function f with a loop in it
;;;;    -- is memoised instead: the call becomes (memo-call M (f ..) KEY
;;;;    ..), a table from the key to the value (scm2cpp.hpp's memo_get),
;;;;    allocated before the loop, and f runs once per distinct key.  The
;;;;    key is what is not invariant: the scalar arguments that vary in
;;;;    the loop and, for an array argument filled in the loop by a fill
;;;;    of the kind above (any expression of invariant reads), the values
;;;;    the fill depends on -- its varying scalars, and (memo-range IDX K)
;;;;    for an index array read as IDX[c] over a loop of K.  Every array
;;;;    argument must be invariant or such a fill, and at least one must
;;;;    be an array.  When the filled array is a local that nothing but
;;;;    the fill and this call reads, the fill moves into the miss path:
;;;;    a helper function (fill, then f) is what the memo calls.
;;;;
;;;; What counts as invariant in L: a variable L neither assigns (set!,
;;;; vector-set!, the array writes) nor binds, nor passes bare to a
;;;; function of the program that may write its arguments.  A gathered
;;;; or filled array must be declared, with the fill's extents, by some
;;;; with-arrays of the function -- the shape that says the fill writes
;;;; all of it and that E(v) indexes within x's axis -- and its fill
;;;; must stand earlier in the same statement list as its use, nothing
;;;; in between writing what the fill reads.  The pass works within one
;;;; function: a product formed in a callee of the loop is not seen.
;;;;
;;;; The table is formed lazily, under a flag, so a loop that never
;;;; reaches the product never pays for it; what it trades is a product
;;;; over the full axes once for one over the gathered ones per
;;;; iteration, which pays from the second iteration when the gather
;;;; keeps most of each axis.  No guard is derived for that, and the
;;;; memo grows with the distinct keys of the loop (no eviction).

(require (only-in (file "rewrite-incremental.scm") walk-collect written-vars))

(provide hoist-invariant-products memo-invariant-calls program-context)

;; ---- the program's functions ----

;; DEFS: name -> (define (f ps ..) body ..).  Returns (values pure?
;; costly?): pure -- writes nothing but its own locals, prints nothing,
;; calls only pure functions; costly -- has a loop, or calls a costly
;; function.
(define (program-context defs)
  (define (body-of f)
    (match (hash-ref defs f #f) [`(define (,_ ,@_) ,@b) b] [_ #f]))
  (define (user-calls b)
    (remove-duplicates
     (for/list ([x (walk-collect pair? b)]
                #:when (and (symbol? (car x)) (hash-has-key? defs (car x))))
       (car x))))
  (define pure-memo (make-hasheq))
  (define (pure? f)
    (cond
      [(hash-has-key? pure-memo f) (hash-ref pure-memo f)]
      [else
       (hash-set! pure-memo f #t)            ; a cycle assumes the best
       (define b (body-of f))
       (define r
         (and b
              (subset? (written-vars b) (binders b))
              (null? (walk-collect (lambda (e) (memq e '(display newline write hash-set! memo-call))) b))
              (for/and ([g (user-calls b)]) (pure? g))))
       (hash-set! pure-memo f r)
       r]))
  (define costly-memo (make-hasheq))
  (define (costly? f)
    (cond
      [(hash-has-key? costly-memo f) (hash-ref costly-memo f)]
      [else
       (hash-set! costly-memo f #f)
       (define b (body-of f))
       (define r
         (and b
              (or (pair? (walk-collect (lambda (e) (match e [`(do ,(? list?) ,_ ...) #t]
                                                         [`(let ,(? symbol?) ,_ ...) #t]
                                                         [_ #f]))
                                       b))
                  (for/or ([g (user-calls b)]) (costly? g)))))
       (hash-set! costly-memo f r)
       r]))
  (values pure? costly?))

;; ---- what a loop leaves alone ----

;; Variables bound anywhere inside E.
(define (binders e)
  (for/fold ([s (seteq)]) ([x (walk-collect pair? e)])
    (match x
      [`(,(or 'let 'let* 'letrec 'do) ,(? list? bs) ,_ ...)
       (for/fold ([s s]) ([b bs])
         (match b [`(,(? symbol? v) ,_ ...) (set-add s v)] [_ s]))]
      [`(let ,(? symbol? nm) ,(? list? bs) ,_ ...)
       (for/fold ([s (set-add s nm)]) ([b bs])
         (match b [`(,(? symbol? v) ,_ ...) (set-add s v)] [_ s]))]
      [`(lambda ,(? list? ps) ,_ ...) (set-union s (list->seteq (filter symbol? ps)))]
      [_ s])))

;; Variables passed bare to a function of the program that may write
;; its arguments, inside E.
(define (call-args e writes?)
  (for/fold ([s (seteq)]) ([x (walk-collect pair? e)])
    (match x
      [`(,(? symbol? f) ,args ...)
       #:when (writes? f)
       (set-union s (list->seteq (filter symbol? args)))]
      [_ s])))

(define (variant-set e writes?)
  (set-union (written-vars e) (binders e) (call-args e writes?)))

;; every symbol in an expression, heads aside
(define (symbols-of e)
  (match e
    [(? symbol?) (list e)]
    [`(,_ ,args ...) (append-map symbols-of args)]
    [_ '()]))

;; the variables E reads that it does not bind, in order of appearance
(define (free-vars e fns)
  (define out '())
  (define (note! v) (unless (memq v out) (set! out (cons v out))))
  (let go ([e e] [bound '()])
    (match e
      [(? symbol?) (unless (or (memq e bound) (memq e fns)) (note! e))]
      [`(do ,(? list? bs) ,test ,body ...)
       (define vs (filter-map (lambda (b) (and (pair? b) (car b))) bs))
       (for ([b bs]) (match b [`(,_ ,i ,s ...) (go i bound) (for ([x s]) (go x (append vs bound)))] [_ (void)]))
       (for ([x (cons test body)]) (go x (append vs bound)))]
      [`(let ,(? list? bs) ,body ...)
       (for ([b bs]) (match b [`(,_ ,i) (go i bound)] [_ (void)]))
       (define vs (filter-map (lambda (b) (and (pair? b) (car b))) bs))
       (for ([x body]) (go x (append vs bound)))]
      [`(,(? symbol?) ,args ...) (for ([a args]) (go a bound))]
      [(? pair?) (for ([a e]) (go a bound))]
      [_ (void)]))
  (reverse out))

(define (subst e from to)
  (cond [(eq? e from) to]
        [(pair? e) (map (lambda (x) (subst x from to)) e)]
        [else e]))

(define (occurrences v e) (length (walk-collect (lambda (x) (eq? x v)) e)))

;; E without its with-arrays declarations (a shape is not a read)
(define (strip-decls e)
  (match e
    [`(with-arrays ,(? list?) ,body ...) `(with-arrays () ,@(map strip-decls body))]
    [(? pair?) (map strip-decls e)]
    [_ e]))

;; ---- flat indices ----

;; E split against row-major DIMS (D1 .. Dr), the Horner form the
;; subset writes -- (+ (* (+ (* u1 D2) u2) D3) u3) and the orders of
;; each sum and product -- as (u1 .. ur), or #f.
(define (split-index e dims)
  (cond
    [(null? dims) #f]
    [(null? (cdr dims)) (list e)]
    [else
     (define d (last dims))
     (define outer (drop-right dims 1))
     (define (try w u) (let ([ws (split-index w outer)]) (and ws (append ws (list u)))))
     (define (term t) (match t [`(* ,w ,(== d)) w] [`(* ,(== d) ,w) w] [_ #f]))
     (match e
       [`(+ ,a ,b) (or (let ([w (term a)]) (and w (try w b)))
                       (let ([w (term b)]) (and w (try w a))))]
       [_ #f])]))

(define (build-index es dims)
  (for/fold ([acc (car es)]) ([e (cdr es)] [d (cdr dims)])
    `(+ (* ,acc ,d) ,e)))

;; ---- fills ----

;; A nest of counting loops around one (vector-set! A IA RHS), as
;; (list A IA RHS loops) with loops ((v . bound) ..) outermost first.
(define (parse-fill s)
  (let loop ([s s] [loops '()])
    (match s
      [`(do ((,(? symbol? v) 0 (+ ,v2 1))) ((= ,v3 ,b)) ,body)
       #:when (and (eq? v v2) (eq? v v3))
       (loop body (cons (cons v b) loops))]
      [`(vector-set! ,(? symbol? a) ,ia ,rhs)
       #:when (pair? loops)
       (list a ia rhs (reverse loops))]
      [_ #f])))

;; The fill writes all of A, declared ADIMS: its index splits against
;; them into the loop variables, each once, each over its axis's extent.
(define (fill-covers? fp adims)
  (match-define (list _ ia _ loops) fp)
  (define vars (map car loops))
  (define ias (split-index ia adims))
  (and ias
       (= (length ias) (length vars))
       (andmap symbol? ias)
       (= (length (remove-duplicates ias)) (length vars))
       (andmap (lambda (v) (memq v vars)) ias)
       (andmap (lambda (v d) (equal? (cdr (assq v loops)) d)) ias adims)))

(define (dims-in decls o)
  (for/or ([d decls]) (and (eq? (car d) o) (cadr d))))

;; The with-arrays declarations anywhere in BODY: (name dims) pairs.
(define (all-decls body)
  (for*/list ([x (walk-collect pair? body)]
              #:when (match x [`(with-arrays ,(? list?) ,_ ...) #t] [_ #f])
              [d (cadr x)]
              #:when (match d [`(,(? symbol?) ,(? list?)) #t] [_ #f]))
    d))

;; The nearest statement before J in SS that is a fill of A covering
;; one of A's declarations, with nothing from it up to and including
;; SS[J] writing what it reads: (values fill-stmt parsed adims) or #f.
(define (find-fill a ss j decls-of-a writes?)
  (let loop ([f (- j 1)])
    (cond
      [(< f 0) (values #f #f #f)]
      [(let ([fp (parse-fill (list-ref ss f))]) (and fp (eq? (car fp) a) fp))
       => (lambda (fp)
            (define adims (for/or ([d decls-of-a]) (and (fill-covers? fp d) d)))
            (define vars (map car (cadddr fp)))
            (define reads (remove* vars (remove-duplicates
                                         (append (list a) (symbols-of (cadr fp)) (symbols-of (caddr fp))
                                                 (append-map (lambda (l) (symbols-of (cdr l))) (cadddr fp))))))
            (define after `(begin ,@(for/list ([b (in-range (+ f 1) (+ j 1))]) (list-ref ss b))))
            (define w (variant-set after writes?))
            (if (and adims (not (for/or ([v reads]) (and (not (eq? v a)) (set-member? w v))))
                     ;; a itself only by the statements before the use
                     (not (set-member? (variant-set `(begin ,@(for/list ([b (in-range (+ f 1) j)]) (list-ref ss b)))
                                                    writes?)
                                       a)))
                (values (list-ref ss f) fp adims)
                (values #f #f #f)))]
      [else (loop (- f 1))])))

;; ---- 1. products ----

;; The product on the right of (array-set! G RHS) as a contraction
;; (list ks ys (a la ..) (b lb ..)), or #f.
(define (as-contract rhs decls)
  (define (rank o) (let ([d (dims-in decls o)]) (and d (length d))))
  (define s (gensym 's))
  (define r (gensym 'r))
  (define c (gensym 'c))
  (match rhs
    [`(contract ,(? list? ks) ,(? list? ys) (,(? symbol? a) ,(? symbol? la) ...) (,(? symbol? b) ,(? symbol? lb) ...))
     (and (eqv? (rank a) (length la)) (eqv? (rank b) (length lb))
          (list ks ys (cons a la) (cons b lb)))]
    [`(matmul (transpose ,(? symbol? a)) ,(? symbol? b))
     (and (eqv? (rank a) 2)
          (case (rank b)
            [(2) (list (list s) (list r c) (list a s r) (list b s c))]
            [(1) (list (list s) (list r) (list a s r) (list b s))]
            [else #f]))]
    [`(matmul ,(? symbol? a) (transpose ,(? symbol? b)))
     (and (eqv? (rank a) 2) (eqv? (rank b) 2)
          (list (list s) (list r c) (list a r s) (list b c s)))]
    [`(matmul ,(? symbol? a) ,(? symbol? b))
     (and (eqv? (rank a) 2)
          (case (rank b)
            [(2) (list (list s) (list r c) (list a r s) (list b s c))]
            [(1) (list (list s) (list r) (list a r s) (list b s))]
            [else #f]))]
    [_ #f]))

;; An operand as its source: (list x xdims amap) where amap gives, for
;; each axis of the operand, (list x-axis kind e v) -- kind full (the
;; axis is x's own, e #f) or gather (x's axis is indexed by e, an
;; expression of the loop variable v).
(define (gather-source fp adims fdecls inv?)
  (match-define (list a ia rhs loops) fp)
  (define vars (map car loops))
  (define ias (split-index ia adims))
  (match rhs
    [`(vector-ref ,(? symbol? x) ,ix)
     #:when (inv? x)
     (for/or ([d fdecls] #:when (and (eq? (car d) x) (= (length (cadr d)) (length vars))))
       (define xdims (cadr d))
       (define ixs (split-index ix xdims))
       (and ixs (andmap inv? xdims)
            (let ([kinds
                   (for/list ([e ixs] [xd xdims])
                     (cond
                       [(memq e vars) (and (equal? (cdr (assq e loops)) xd) (list e 'full #f))]
                       [else
                        (let ([vs (filter (lambda (v) (memq v (symbols-of e))) vars)])
                          (and (= (length vs) 1) (list (car vs) 'gather e)))]))])
              (and (andmap values kinds)
                   (= (length (remove-duplicates (map car kinds))) (length vars))
                   (list x xdims
                         (for/list ([v ias])
                           (let ([xa (index-of (map car kinds) v)])
                             (match (list-ref kinds xa)
                               [(list _ kind e) (list xa kind e v)]))))))))]
    [_ #f]))

;; Try loop L.  Returns the replacement or #f.
(define (hoist-loop L writes? fdecls)
  (define var (variant-set L writes?))
  (define (inv? s) (or (number? s) (and (symbol? s) (not (set-member? var s)))))
  (define tables '())        ; (key T FL size hoisted-decls product)
  (define fills '())         ; (fill-stmt . array)
  ;; (list x xdims amap fill) for operand O at J of SS, or #f
  (define (operand o decls ss j)
    (define od (dims-in decls o))
    (cond
      [(not od) #f]
      [(and (inv? o) (andmap inv? od))
       (list o od (for/list ([k (length od)]) (list k 'full #f #f)) #f)]
      [else
       (define-values (fill fp adims)
         (find-fill o ss j (list od) writes?))
       (and fill
            (let ([src (gather-source fp adims fdecls inv?)])
              (and src (append src (list fill)))))]))
  ;; the table and the lookup for G = contract(ks, ys, A, B), or #f
  (define (tabulate g decls nc ss j)
    (match-define (list ks ys (cons a la) (cons b lb)) nc)
    (define oa (operand a decls ss j))
    (define ob (and oa (operand b decls ss j)))
    (define gd (dims-in decls g))
    (and
     oa ob gd (= (length gd) (length ys))
     (let ()
       (match-define (list xa xad ama fa) oa)
       (match-define (list xb xbd amb fb) ob)
       ;; the label on each axis of the sources
       (define (src-labels amap labs rank)
         (let ([v (make-vector rank #f)])
           (for ([m amap] [l labs]) (vector-set! v (car m) l))
           (vector->list v)))
       (define xl (src-labels ama la (length xad)))
       (define zl (src-labels amb lb (length xbd)))
       ;; every carrier of a label: (kind e v extent)
       (define (carriers l)
         (append (for/list ([m ama] [x la] #:when (eq? x l)) (list (cadr m) (caddr m) (cadddr m) (list-ref xad (car m))))
                 (for/list ([m amb] [x lb] #:when (eq? x l)) (list (cadr m) (caddr m) (cadddr m) (list-ref xbd (car m))))))
       (and
        (andmap (lambda (k) (andmap (lambda (c) (eq? (car c) 'full)) (carriers k))) ks)
        (andmap (lambda (y) (let ([cs (carriers y)])
                              (and (pair? cs)
                                   (or (null? (cdr cs)) (andmap (lambda (c) (eq? (car c) 'full)) cs)))))
                ys)
        (let* ([tdims (for/list ([y ys]) (cadddr (car (carriers y))))]
               [rename (lambda (l) (cond [(index-of ys l) => (lambda (i) (format "Y~a" i))]
                                         [(index-of ks l) => (lambda (i) (format "K~a" i))]
                                         [else l]))]
               [key (list xa (map rename xl) xad xb (map rename zl) xbd)]
               [tb (or (assoc key tables)
                       (let* ([t (gensym 'inv)] [fl (gensym 'invok)]
                              [hd (remove-duplicates
                                   (list (list xa xad) (list xb xbd) (list t tdims))
                                   (lambda (u v) (eq? (car u) (car v))))]
                              [row (list key t fl (if (null? (cdr tdims)) (car tdims) `(* ,@tdims)) hd
                                         `(array-set! ,t (contract ,ks ,ys (,xa ,@xl) (,xb ,@zl))))])
                         (set! tables (append tables (list row)))
                         row))])
          (match-define (list _ t fl _ hd prod) tb)
          (for ([fz (list fa fb)] [o (list a b)] #:when fz)
            (set! fills (cons (cons fz o) fills)))
          (define gs (for/list ([y ys]) (gensym 'g)))
          (define mapped
            (for/list ([y ys] [gv gs])
              (match (car (carriers y))
                [(list 'gather e v _) (subst e v gv)]
                [_ gv])))
          (define inner `(vector-set! ,g ,(build-index gs gd) (vector-ref ,t ,(build-index mapped tdims))))
          `(begin
             (if (= ,fl 0) (begin (with-arrays ,hd ,prod) (set! ,fl 1)) 0)
             ,(for/fold ([body inner]) ([gv (reverse gs)] [d (reverse gd)])
                `(do ((,gv 0 (+ ,gv 1))) ((= ,gv ,d)) ,body))))))))
  (define (rewrite-list ss)
    (for/list ([s ss] [j (in-naturals)])
      (match s
        [`(with-arrays ,decls (array-set! ,(? symbol? g) ,rhs))
         (define nc (as-contract rhs decls))
         (or (and nc (tabulate g decls nc ss j)) s)]
        [_ s])))
  (define new (map-stmt-lists rewrite-list L))
  (cond
    [(null? tables) #f]
    [else
     ;; a fill whose array the loop no longer reads is dead
     (define trimmed
       (for/fold ([e new]) ([fo (remove-duplicates fills)])
         (let ([e2 (drop-stmt e (car fo))])
           (if (zero? (occurrences (cdr fo) e2)) e2 e))))
     `(let ,(append (for/list ([tb tables]) `(,(list-ref tb 1) (make-vector ,(list-ref tb 3) 0.0)))
                    (for/list ([tb tables]) `(,(list-ref tb 2) 0)))
        ,trimmed)]))

;; ---- statement lists ----

;; E with F applied to every statement list in it, innermost first.
(define (map-stmt-lists f e)
  (define (go e) (map-stmt-lists f e))
  (match e
    [`(begin ,ss ...) `(begin ,@(f (map go ss)))]
    [`(let ,(? list? bs) ,ss ...) `(let ,bs ,@(f (map go ss)))]
    [`(let ,(? symbol? nm) ,bs ,ss ...) `(let ,nm ,bs ,@(f (map go ss)))]
    [`(do ,bs ,test ,ss ...) `(do ,bs ,test ,@(f (map go ss)))]
    [`(with-arrays ,ds ,ss ...) `(with-arrays ,ds ,@(f (map go ss)))]
    [(? pair?) (map go e)]
    [_ e]))

(define (drop-stmt e victim)
  (map-stmt-lists (lambda (ss) (filter (lambda (s) (not (equal? s victim))) ss)) e))

;; every loop of BODY offered to TRY, outermost first; a loop TRY
;; rewrites is not entered again
(define (over-loops body try)
  (define fired #f)
  (define (go e)
    (match e
      [`(do ,(? list?) ,(? list?) ,_ ...)
       (cond [(try e) => (lambda (n) (set! fired #t) n)]
             [else (map go e)])]
      [(? pair?) (map go e)]
      [_ e]))
  (values (map go body) fired))

;; BODY with every loop that has an invariant product rewritten; DEFS
;; the program's functions.  Returns the body and whether anything fired.
(define (hoist-invariant-products body defs)
  (define-values (pure? costly?) (program-context defs))
  (define (writes? f) (and (hash-has-key? defs f) (not (pure? f))))
  (define fdecls (all-decls body))
  (over-loops body (lambda (L) (hoist-loop L writes? fdecls))))

;; ---- 2. calls ----

;; The arrays of a function body: what it indexes, declares or allocates.
(define (array-names body)
  (for/fold ([s (seteq)]) ([x (walk-collect pair? body)])
    (match x
      [`(,(or 'vector-ref 'vector-set! 'vector-length 'array-ref 'array-set!) ,(? symbol? a) ,_ ...) (set-add s a)]
      [`(,(? symbol?) (,(? symbol? a) (make-vector ,_ ...))) (set-add s a)]
      [`(,(? symbol? a) (,(or 'make-vector 'vector) ,_ ...)) (set-add s a)]
      [_ s])))

;; BODY (of function FNAME) with the pure costly calls of every loop
;; memoised.  Returns the body, whether anything fired, and the helper
;; definitions the moved fills need.
(define (memo-invariant-calls body defs fname)
  (define-values (pure? costly?) (program-context defs))
  (define (writes? f) (and (hash-has-key? defs f) (not (pure? f))))
  (define fdecls (all-decls body))
  (define arrays
    (set-union (array-names body) (list->seteq (map car fdecls))))
  (define fns (hash-keys defs))
  (define helpers '())
  ;; is A a let-bound local of the function (not a parameter)?
  (define locals
    (for*/fold ([s (seteq)]) ([x (walk-collect pair? body)])
      (match x
        [`(let ,(? list? bs) ,_ ...)
         (for/fold ([s s]) ([b bs]) (match b [`(,(? symbol? v) ,_) (set-add s v)] [_ s]))]
        [_ s])))
  (define (param-arrays f)
    (match (hash-ref defs f #f)
      [`(define (,_ ,@ps) ,@b) (let ([as (array-names b)]) (for/list ([p ps]) (set-member? as p)))]
      [_ #f]))
  (define (memo-loop L)
    (define var (variant-set L writes?))
    (define (inv? s) (or (number? s) (and (symbol? s) (not (set-member? var s)))))
    (define memos '())
    (define moved '())        ; fills to drop
    ;; the key of a call at J of SS, and the fill it may move: (list keys
    ;; fill) or #f
    (define (call-key call ss j)
      (match-define `(,f ,@args) call)
      (define pa (param-arrays f))
      (define keys '())
      (define fill-used #f)
      (define n-arrays 0)
      (define (key! k) (unless (member k keys) (set! keys (append keys (list k)))))
      (define ok
        (for/and ([a args] [pk (or pa (map (lambda (_) #f) args))])
          (cond
            [(and (symbol? a) (or pk (set-member? arrays a)))
             (set! n-arrays (+ n-arrays 1))
             (cond
               [(inv? a) #t]
               [else
                (define-values (fill fp adims)
                  (find-fill a ss j (filter-map (lambda (d) (and (eq? (car d) a) (cadr d))) fdecls) writes?))
                (and fill
                     (let* ([loops (cadddr fp)]
                            [vars (map car loops)]
                            [rhs (caddr fp)]
                            [ok (for/and ([x (walk-collect pair? rhs)])
                                  ;; an array the fill reads: invariant, or
                                  ;; read at a loop variable alone
                                  (match x
                                    [`(vector-ref ,(? symbol? s) ,ix)
                                     (cond [(inv? s) #t]
                                           [(and (memq ix vars) (set-member? arrays s))
                                            (key! `(memo-range ,s ,(cdr (assq ix loops)))) #t]
                                           [else #f])]
                                    [_ #t]))])
                       (and ok
                            (begin
                              (for ([v (remove* vars (remove-duplicates
                                                      (append (symbols-of rhs)
                                                              (append-map (lambda (l) (symbols-of (cdr l))) loops))))]
                                    #:unless (or (inv? v) (set-member? arrays v)))
                                (key! v))
                              (when (and (set-member? locals a)
                                         (not fill-used))
                                (set! fill-used fill))
                              #t))))])]
            [(symbol? a) (unless (inv? a) (key! a)) #t]
            [(andmap inv? (symbols-of a)) #t]
            [else (key! a) #t])))
      (and ok (> n-arrays 0) (list keys fill-used)))
    (define (rewrite-list ss)
      (for/list ([s ss] [j (in-naturals)])
        (let go ([e s])
          (match e
            [`(memo-call ,_ ...) e]
            [`(,(? symbol? f) ,args ...)
             #:when (and (hash-has-key? defs f) (not (eq? f fname)) (pure? f) (costly? f))
             (define ck (call-key e ss j))
             (cond
               [ck
                (match-define (list keys fill) ck)
                (define m (gensym 'memo))
                (set! memos (cons m memos))
                (define a (and fill (car (parse-fill fill))))
                (define call
                  (cond
                    ;; the fill moves into the miss path when nothing
                    ;; else in the function reads its array
                    [(and fill
                          (= (occurrences a (strip-decls body))
                             (+ 1 (occurrences a fill) (occurrences a e))))
                     (define h (string->symbol (format "~a-miss~a" f (length helpers))))
                     (define ps (free-vars `(begin ,fill ,e) fns))
                     (set! helpers (cons `(define (,h ,@ps) ,fill ,e) helpers))
                     (set! moved (cons fill moved))
                     `(,h ,@ps)]
                    [else e]))
                `(memo-call ,m ,call ,@keys)]
               [else (map go e)])]
            [(? pair?) (map go e)]
            [_ e]))))
    (define new (map-stmt-lists rewrite-list L))
    (cond
      [(null? memos) #f]
      [else
       `(let ,(for/list ([m (reverse memos)]) `(,m (make-hash)))
          ,(for/fold ([e new]) ([f moved]) (drop-stmt e f)))]))
  (define-values (out fired) (over-loops body memo-loop))
  (values out fired (reverse helpers)))

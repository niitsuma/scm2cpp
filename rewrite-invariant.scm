#lang racket
;;;; Products of loop-invariant arrays, tabulated once (--derive).
;;;;
;;;; A loop that forms, every time round, a product of columns gathered
;;;; from an array it never writes --
;;;;
;;;;   (do (..) (..)
;;;;     ..
;;;;     (do ((i 0 (+ i 1))) ((= i n))              ; the gather: xk = X[:, idx]
;;;;       (do ((c 0 (+ c 1))) ((= c k))
;;;;         (vector-set! xk (+ (* i k) c) (vector-ref x (+ (* i p) (vector-ref idx c))))))
;;;;     (with-arrays ((xk (n k)) (gk (k k)))
;;;;       (array-set! gk (matmul (transpose xk) xk)))
;;;;     ..)
;;;;
;;;; -- computes entries of one fixed table, X'X, again and again: gk[r,c]
;;;; is sum_i x[i,idx[r]] x[i,idx[c]], which is (X'X)[idx[r],idx[c]].  The
;;;; columns xk[:,c] are what the note calls quasi-invariant: an invariant
;;;; array under an operation that costs nothing next to the product (an
;;;; index lookup), so the expensive operation, the inner products, can be
;;;; taken over the invariant array itself, once, and the lookup applied
;;;; to the result instead.  This pass does that: the table T = X'Z is
;;;; allocated before the loop and formed on the loop's first use -- as a
;;;; matmul under with-arrays, so --blas makes it one dsyrk or dgemm --
;;;; and the product becomes the gather of T,
;;;;
;;;;     gk[r,c] = T[idx[r], idx[c]].
;;;;
;;;; The fill of xk is then dead when nothing else in the loop reads xk,
;;;; and goes.  scikit-learn's ARDRegression forms the kept features' Gram
;;;; from X every iteration; ard.scm's HOIST 1 is this rewrite by hand.
;;;;
;;;; What counts as invariant in the loop L: a variable L neither assigns
;;;; (set!, vector-set!, the array writes) nor binds, nor passes bare to a
;;;; function of the program (which might write it).  An operand of the
;;;; product is either such a matrix (or vector, on the right) itself, or
;;;; the gather above of one, xk[i,c] = x[i, E(c)] for any column
;;;; expression E of c, found earlier in the same statement list with
;;;; nothing in between writing xk or anything E, n or k reads.  The
;;;; gathered array must be declared (n p) by some with-arrays of the
;;;; function -- the shape that makes E(c) a column, 0 <= E(c) < p, in a
;;;; program whose reads are in bounds -- and n, p must be invariant too.
;;;; At least one side must be a gather or the whole product is
;;;; invariant; either way the table replaces it.
;;;;
;;;; The table is formed lazily, under a flag, so a loop that never
;;;; reaches the product never pays for it; what it trades is a p-by-p
;;;; product once (and p^2 cells) for an n k^2 one per iteration, which
;;;; pays from the second iteration when k is near p and loses when k is
;;;; much smaller than p from the start.  No guard is derived for that.

(require (only-in (file "rewrite-incremental.scm") walk-collect written-vars))

(provide hoist-invariant-products)

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

;; Variables passed bare to a function of the program inside E.
(define (call-args e user-fns)
  (for/fold ([s (seteq)]) ([x (walk-collect pair? e)])
    (match x
      [`(,(? symbol? f) ,args ...)
       #:when (set-member? user-fns f)
       (set-union s (list->seteq (filter symbol? args)))]
      [_ s])))

(define (variant-set e user-fns)
  (set-union (written-vars e) (binders e) (call-args e user-fns)))

;; the free symbols of an expression (every symbol in it, heads aside)
(define (symbols-of e)
  (match e
    [(? symbol?) (list e)]
    [`(,_ ,args ...) (append-map symbols-of args)]
    [_ '()]))

(define (subst e from to)
  (cond [(eq? e from) to]
        [(pair? e) (map (lambda (x) (subst x from to)) e)]
        [else e]))

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

;; ---- one loop ----

;; The with-arrays declarations anywhere in BODY: (name dims) pairs.
(define (all-decls body)
  (for*/list ([x (walk-collect pair? body)]
              #:when (match x [`(with-arrays ,(? list?) ,_ ...) #t] [_ #f])
              [d (cadr x)]
              #:when (match d [`(,(? symbol?) ,(? list?)) #t] [_ #f]))
    d))

;; Try loop L.  Returns the replacement or #f.
(define (hoist-loop L user-fns fdecls)
  (define var (variant-set L user-fns))
  (define (inv? s) (or (number? s) (and (symbol? s) (not (set-member? var s)))))
  (define tables '())        ; (key T FL size hoisted-decls product)
  (define fills '())         ; (fill-stmt . operand)
  (define (declared-as? x dims)
    (for/or ([d fdecls]) (and (eq? (car d) x) (equal? (cadr d) dims))))
  (define (dims-in decls o)
    (for/or ([d decls]) (and (eq? (car d) o) (cadr d))))
  ;; an operand at position J of SS, as (src stride sel k vec?) -- SEL
  ;; maps an index expression to the column of SRC it reads -- or #f
  (define (operand o decls ss j)
    (match (dims-in decls o)
      [`(,n ,m)
       #:when (and (inv? o) (inv? n) (inv? m))
       (list o m (lambda (r) r) m #f n #f)]
      [`(,n)
       #:when (and (inv? o) (inv? n))
       (list o 1 (lambda (r) r) 1 #t n #f)]
      [`(,n ,k)
       (for/or ([f (in-range (- j 1) -1 -1)])
         (match (list-ref ss f)
           [(and fill
                 `(do ((,i 0 (+ ,i 1))) ((= ,i ,(== n)))
                    (do ((,c 0 (+ ,c 1))) ((= ,c ,(== k)))
                      (vector-set! ,(== o) (+ (* ,i ,(== k)) ,c)
                                   (vector-ref ,(? symbol? x) (+ (* ,i ,p) ,e))))))
            #:when (and (symbol? i) (symbol? c) (not (eq? i c))
                        (inv? x) (inv? n) (inv? p)
                        (not (memq i (symbols-of e)))
                        (declared-as? x (list n p)))
            (let* ([between `(begin ,@(for/list ([b (in-range (+ f 1) j)]) (list-ref ss b)))]
                   [w (variant-set between user-fns)]
                   [reads (cons o (append (symbols-of e) (symbols-of k)))])
              (and (not (for/or ([v reads]) (and (symbol? v) (not (eq? v c)) (set-member? w v))))
                   (list x p (lambda (r) (subst e c r)) k #f n fill)))]
           [_ #f]))]
      [_ #f]))
  (define (rewrite-list ss)
    (for/list ([s ss] [j (in-naturals)])
      (match s
        [`(with-arrays ,decls (array-set! ,(? symbol? gk) (matmul (transpose ,(? symbol? a)) ,(? symbol? b))))
         (define oa (operand a decls ss j))
         (define ob (and oa (operand b decls ss j)))
         (cond
           [(and oa ob (not (list-ref oa 4)) (equal? (list-ref oa 5) (list-ref ob 5)))
            (match-define (list xa pa sa ka _ n fa) oa)
            (match-define (list xb pb sb kb vb _ fb) ob)
            (define key (list xa pa xb pb n vb))
            (define tb
              (or (assoc key tables)
                  (let* ([t (gensym 'inv)] [fl (gensym 'invok)]
                         [hd (remove-duplicates
                              (list (list xa (list n pa)) (list xb (if vb (list n) (list n pb)))
                                    (list t (if vb (list pa) (list pa pb))))
                              (lambda (u v) (eq? (car u) (car v))))]
                         [row (list key t fl (if vb pa `(* ,pa ,pb)) hd
                                    `(array-set! ,t (matmul (transpose ,xa) ,xb)))])
                    (set! tables (append tables (list row)))
                    row)))
            (match-define (list _ t fl _ hd prod) tb)
            (for ([fz (list fa fb)] [o (list a b)] #:when fz)
              (set! fills (cons (cons fz o) fills)))
            (define r (gensym 'r))
            (define c (gensym 'c))
            `(begin
               (if (= ,fl 0) (begin (with-arrays ,hd ,prod) (set! ,fl 1)) 0)
               ,(if vb
                    `(do ((,r 0 (+ ,r 1))) ((= ,r ,ka))
                       (vector-set! ,gk ,r (vector-ref ,t ,(sa r))))
                    `(do ((,r 0 (+ ,r 1))) ((= ,r ,ka))
                       (do ((,c 0 (+ ,c 1))) ((= ,c ,kb))
                         (vector-set! ,gk (+ (* ,r ,kb) ,c)
                                      (vector-ref ,t (+ (* ,(sa r) ,pb) ,(sb c))))))))]
           [else s])]
        [_ s])))
  (define new2 (map-stmt-lists rewrite-list L))
  (cond
    [(null? tables) #f]
    [else
     ;; a fill whose array the loop no longer reads is dead
     (define trimmed
       (for/fold ([e new2]) ([fo (remove-duplicates fills)])
         (let ([e2 (drop-stmt e (car fo))])
           (if (null? (walk-collect (lambda (x) (eq? x (cdr fo))) e2)) e2 e))))
     `(let ,(append (for/list ([tb tables]) `(,(list-ref tb 1) (make-vector ,(list-ref tb 3) 0.0)))
                    (for/list ([tb tables]) `(,(list-ref tb 2) 0)))
        ,trimmed)]))

;; ---- a function body ----

;; BODY with every loop that has an invariant product rewritten, the
;; outermost loop first; USER-FNS the names the program defines.
;; Returns the body and whether anything fired.
(define (hoist-invariant-products body user-fns)
  (define fdecls (all-decls body))
  (define fired #f)
  (define (go e)
    (match e
      [`(do ,(? list?) ,(? list?) ,_ ...)
       (cond [(hoist-loop e user-fns fdecls) => (lambda (n) (set! fired #t) n)]
             [else (map go e)])]
      [(? pair?) (map go e)]
      [_ e]))
  (define out (map go body))
  (values out fired))

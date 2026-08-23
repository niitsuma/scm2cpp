#lang racket
;;;; The representation step for the lag sums the normalization pass
;;;; exposes: (array-sum (* (slice V a ..) (slice V b ..))) depends on
;;;; its coordinates only through the shift b - a and the window, so
;;;; the whole family of such folds is answerable from one prefix
;;;; table indexed by lag -- cs[d][t+1] = cs[d][t] + V[t]*V[t+d] --
;;;; and every fold becomes a two-point difference.  This is the
;;;; slice-sum lowering the -I machinery lacked, generalized from one
;;;; running sum to a lag-indexed family of them; on the normalized
;;;; Gram element of a moving-average design the emitted build is
;;;; build-S of the hand-written covariance kernel.
;;;;
;;;; Everything symbolic is kept affine.  Offsets, lags and extents
;;;; are linear forms over loop coordinates and invariant symbols;
;;;; the lag range comes from interval arithmetic over the
;;;; coordinates' extents.  Comparisons of symbolic bounds use the
;;;; only fact available -- an extent that reaches a loop is at least
;;;; one -- and anything incomparable under that assumption refuses,
;;;; as does any offset that is not affine with unit coefficient.
;;;;
;;;; The intermediate q array of the hand-written kernel disappears:
;;;; the guarded product accumulates straight into the prefix row, so
;;;; the materialization step and the table step fuse into one loop.

(require (only-in (file "rewrite-incremental.scm") walk-collect subst))

(provide lag-terms lag-lower)

;; ---------------- affine linear forms ----------------

;; (const . ((sym . coeff) ...)), coefficients never zero.

(define (lin-norm c vs)
  (cons c (sort (filter (lambda (p) (not (zero? (cdr p)))) vs)
                symbol<? #:key car)))

(define (lin-const c) (lin-norm c '()))

(define (lin-add a b)
  (lin-norm (+ (car a) (car b))
            (for/list ([s (remove-duplicates
                           (map car (append (cdr a) (cdr b))))])
              (cons s (+ (cond [(assq s (cdr a)) => cdr] [else 0])
                         (cond [(assq s (cdr b)) => cdr] [else 0]))))))

(define (lin-scale a k)
  (lin-norm (* k (car a))
            (for/list ([p (cdr a)]) (cons (car p) (* k (cdr p))))))

(define (lin-sub a b) (lin-add a (lin-scale b -1)))

(define (linear e)
  (match e
    [(? number?) (lin-const e)]
    [(? symbol?) (lin-norm 0 (list (cons e 1)))]
    [`(+ ,a ,b) (let ([x (linear a)] [y (linear b)]) (and x y (lin-add x y)))]
    [`(- ,a ,b) (let ([x (linear a)] [y (linear b)]) (and x y (lin-sub x y)))]
    [`(* ,(? number? k) ,a) (let ([x (linear a)]) (and x (lin-scale x k)))]
    [`(* ,a ,(? number? k)) (let ([x (linear a)]) (and x (lin-scale x k)))]
    [_ #f]))

(define (lin->expr l)
  (define acc
    (for/fold ([acc #f]) ([p (cdr l)])
      (define term
        (case (abs (cdr p))
          [(1) (car p)]
          [else `(* ,(abs (cdr p)) ,(car p))]))
      (cond [(not acc) (if (negative? (cdr p)) `(- 0 ,term) term)]
            [(negative? (cdr p)) `(- ,acc ,term)]
            [else `(+ ,acc ,term)])))
  (cond [(not acc) (car l)]
        [(zero? (car l)) acc]
        [(negative? (car l)) `(- ,acc ,(- (car l)))]
        [else `(+ ,acc ,(car l))]))

;; a - b <= 0 for every valuation with all symbols >= 1: each
;; coefficient nonpositive and the value at all-ones nonpositive.
(define (lin<=? a b)
  (let ([d (lin-sub a b)])
    (and (andmap (lambda (p) (<= (cdr p) 0)) (cdr d))
         (<= (+ (car d) (for/sum ([p (cdr d)]) (cdr p))) 0))))

(define (lin-min* ls)
  (for/fold ([m (car ls)]) ([l (cdr ls)])
    (and m (cond [(lin<=? m l) m] [(lin<=? l m) l] [else #f]))))
(define (lin-max* ls)
  (for/fold ([m (car ls)]) ([l (cdr ls)])
    (and m (cond [(lin<=? l m) m] [(lin<=? m l) l] [else #f]))))

;; Interval of a linear form when each coordinate ranges over
;; [0, extent-1] and everything else stays put.
(define (lin-interval l coord-exts)
  (for/fold ([lo (lin-const (car l))] [hi (lin-const (car l))])
            ([p (cdr l)])
    #:break (not lo)
    (match (assq (car p) coord-exts)
      [(cons _ ext)
       (let ([top (let ([le (linear ext)])
                    (and le (lin-scale (lin-sub le (lin-const 1))
                                       (cdr p))))])
         (if (not top)
             (values #f #f)
             (if (positive? (cdr p))
                 (values lo (lin-add hi top))
                 (values (lin-add lo top) hi))))]
      [_ (let ([t (lin-norm 0 (list p))])
           (values (lin-add lo t) (lin-add hi t)))])))

;; ---------------- the terms and the lowering ----------------

;; Same-base, same-length products of slices: (term A B len-form).
(define (lag-terms e)
  (filter values
          (for/list ([x (walk-collect pair? e)])
            (match x
              [`(array-sum (* (slice ,(? symbol? v) ,a1 ,a2)
                              (slice ,(? symbol? v2) ,b1 ,b2)))
               #:when (eq? v v2)
               (let ([la1 (linear a1)] [la2 (linear a2)]
                     [lb1 (linear b1)] [lb2 (linear b2)])
                 (and la1 la2 lb1 lb2
                      (equal? (lin-sub la2 la1) (lin-sub lb2 lb1))
                      (list x v a1 b1 (lin-sub la2 la1))))]
              [_ #f]))))

;; Lower every lag term of EXPR against one table.  base-exts maps the
;; base array to its extent, coord-exts each loop coordinate to its
;; extent.  Returns (list decl build rewritten) or #f: decl is the
;; with-arrays entry for the table, build the statement that fills it,
;; rewritten the expression with every fold a two-point difference.
(define (lag-lower expr base-exts coord-exts)
  (define terms (lag-terms expr))
  (and (pair? terms)
       (let ([vs (remove-duplicates (map cadr terms))])
         (and (= 1 (length vs))
              (assq (car vs) base-exts)
              (let* ([V (car vs)]
                     [N (cdr (assq V base-exts))]
                     [Ds (for/list ([t terms])
                           (lin-sub (or (linear (cadddr t)) (lin-const 0))
                                    (or (linear (caddr t)) (lin-const 0))))]
                     [ivs (for/list ([D Ds])
                            (let-values ([(lo hi) (lin-interval D coord-exts)])
                              (and lo (cons lo hi))))])
                (and (andmap values ivs)
                     (andmap (lambda (t) (linear (caddr t))) terms)
                     (let* ([lo (lin-min* (map car ivs))]
                            [hi (lin-max* (map cdr ivs))])
                       (and lo hi
                            (let* ([lags (lin->expr
                                          (lin-add (lin-sub hi lo)
                                                   (lin-const 1)))]
                                   [cs (gensym 'cs)]
                                   [dd (gensym 'dd)]
                                   [tt (gensym 't)]
                                   [d (lin->expr
                                       (lin-add (lin-norm 0 (list (cons dd 1)))
                                                lo))]
                                   [build
                                    `(range-for (,dd ,lags)
                                       (begin
                                         (array-set! ,cs ,dd 0 0.0)
                                         (range-for (,tt ,N)
                                           (array-set! ,cs ,dd (+ ,tt 1)
                                             (+ (array-ref ,cs ,dd ,tt)
                                                (if (< (+ ,tt ,d) 0)
                                                    0.0
                                                    (if (< (+ ,tt ,d) ,N)
                                                        (* (vector-ref ,V ,tt)
                                                           (vector-ref ,V (+ ,tt ,d)))
                                                        0.0)))))))]
                                   [rewritten
                                    (for/fold ([e expr]) ([t terms] [D Ds])
                                      (match-define (list site _ a1 b1 len) t)
                                      (subst site
                                             `(- (array-ref ,cs
                                                            ,(lin->expr (lin-sub D lo))
                                                            ,(lin->expr
                                                              (lin-add (linear a1) len)))
                                                 (array-ref ,cs
                                                            ,(lin->expr (lin-sub D lo))
                                                            ,a1))
                                             e))])
                              (list (list cs (list lags `(+ ,N 1)))
                                    build
                                    rewritten))))))))))

#lang racket
;;;; Finite differencing over the array algebra: derive the covariance
;;;; update instead of pattern-matching for it.
;;;;
;;;; cd-covariance-update recognises the whole naive sweep at once and
;;;; replaces it with the Gram-matrix form -- one monolithic pattern, one
;;;; monolithic builder. This module derives the same transformation from
;;;; three local facts, each checked separately:
;;;;
;;;;   1. every READ of the scratch vector v is an instance of one linear
;;;;      context, C_k[v] = (array-sum (* (row X k) v));
;;;;   2. every WRITE to v is an affine update,
;;;;      (array-dec! v (scale d (row X j)));
;;;;   3. the context is linear, so it commutes with the update:
;;;;      C_k[v - d*X_j] = C_k[v] - d * C_k[X_j].
;;;;
;;;; Then a memo vector c with c_k = C_k[v] can be maintained instead of
;;;; v: initialise it once, replace each read by (array-ref c k), replace
;;;; each write by the pushed-through decrement -- whose kernel
;;;; C_k[X_j] = X_k . X_j does not mention v at all, and hoisting it out
;;;; of the sweeps IS the Gram matrix. Nothing here knows the word
;;;; "lasso"; the Gram form appears because the algebra says it must.
;;;;
;;;; v itself: if the liveness pass says v is scratch, its maintenance
;;;; simply disappears. If v is an output, it is restored once at the
;;;; end from the total movement of the coefficients, exactly as the
;;;; hand-written rule does. The restoration is emitted here
;;;; unconditionally; dropping it under a scratch verdict is the caller's
;;;; one-line decision.
;;;;
;;;; The derivation works on the pre-expansion algebra (row, scale,
;;;; array-sum, array-dec!), where linearity is a syntactic property of
;;;; four node types. After macro expansion the same facts are spread
;;;; over loop nests and named lets, which is why the monolithic rule
;;;; needed to match all of them at once.

(provide incrementalize)

(define (sexp-count v e)
  (cond [(eq? v e) 1]
        [(pair? e) (+ (sexp-count v (car e)) (sexp-count v (cdr e)))]
        [else 0]))

;; All read instances (array-sum (* (row X k) v)) of v in E.
(define (read-sites v e)
  (match e
    [`(array-sum (* (row ,x ,k) ,(== v))) (list (list x k e))]
    [(? pair?) (append (read-sites v (car e)) (read-sites v (cdr e)))]
    [_ '()]))

;; All update instances (array-dec! v (scale d (row X j))) of v in E.
(define (update-sites v e)
  (match e
    [`(array-dec! ,(== v) (scale ,d (row ,x ,j))) (list (list x j d e))]
    [(? pair?) (append (update-sites v (car e)) (update-sites v (cdr e)))]
    [_ '()]))

(define (replace-form old new e)
  (cond [(equal? e old) new]
        [(pair? e) (cons (replace-form old new (car e))
                         (replace-form old new (cdr e)))]
        [else e]))

;; incrementalize: SWEEP is the algebra-level loop nest; V the vector to
;; eliminate from it; X its pairing matrix; P and N its extents; BETA the
;; coefficient vector whose movement restores V. Returns
;;   (values preamble sweep' restoration)
;; or #f when one of the three facts fails to hold.
(define (incrementalize sweep v x p n beta)
  (define reads (read-sites v sweep))
  (define updates (update-sites v sweep))
  (define occurrences (sexp-count v sweep))
  (define accounted (+ (apply + (map (lambda (r) (sexp-count v (caddr r))) reads))
                       (apply + (map (lambda (u) (sexp-count v (cadddr u))) updates))))
  (and
   (pair? reads) (pair? updates)
   ;; fact 1 and 2: same pairing matrix everywhere
   (for/and ([r reads]) (eq? (car r) x))
   (for/and ([u updates]) (eq? (car u) x))
   ;; fact 3's precondition: v occurs nowhere else -- every occurrence is
   ;; inside a recognised linear read or a recognised affine update, so
   ;; pushing the context through the update accounts for all of v
   (= occurrences accounted)
   (let ([c  (gensym 'c)] [g (gensym 'g)]
         [k1 (gensym 'k)] [k2 (gensym 'k)] [b0 (gensym 'b0)] [jj (gensym 'j)])
     (define sweep2
       (for/fold ([e sweep])
                 ([u updates])
         (match-define (list _x j d site) u)
         (replace-form site `(array-dec! ,c (scale ,d (row ,g ,j)))
                       (for/fold ([e2 e]) ([r reads])
                         (match-define (list _x2 k rsite) r)
                         (replace-form rsite `(array-ref ,c ,k) e2)))))
     ;; one derived block: allocations, the hoisted kernel -- the Gram
     ;; matrix -- the memo, the transformed sweeps, and the restoration.
     ;; The restoration is exact because v was linear state: its total
     ;; change is the sum of the per-coordinate changes, applied once.
     ;; Under a scratch verdict from the liveness pass the caller may
     ;; drop the final range-for; nothing else references v.
     `(let ((,g (make-vector (* ,p ,p) 0.0))
            (,c (make-vector ,p 0.0))
            (,b0 (make-vector ,p 0.0)))
        (with-arrays ((,g (,p ,p)) (,c (,p)))
          (range-for (,k1 ,p)
            (range-for (,k2 ,p)
              (array-set! ,g ,k1 ,k2
                          (array-sum (* (row ,x ,k1) (row ,x ,k2))))))
          (range-for (,k1 ,p)
            (array-set! ,c ,k1 (array-sum (* (row ,x ,k1) ,v))))
          (range-for (,k1 ,p)
            (vector-set! ,b0 ,k1 (vector-ref ,beta ,k1)))
          ,sweep2
          (range-for (,jj ,p)
            (array-dec! ,v (scale (- (vector-ref ,beta ,jj)
                                     (vector-ref ,b0 ,jj))
                                  (row ,x ,jj))))
          0)))))

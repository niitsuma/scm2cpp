;; Lasso over moving-average features by covariance updates.
;;
;; The design matrix is not arbitrary: column j is the moving average of
;; the base sequence at window j+1, so X[row][j] = (ps[t]-ps[t-w])/w with
;; t = wmax+row. Two consequences are used here.
;;
;; First, the Gram matrix G = X^T X and the vector c = X^T y are built from
;; the prefix sums rather than from X. Writing S(a,b) for the inner product
;; of ps shifted by a and by b over the observation window,
;;
;;   G[j][k] = (S(0,0) - S(0,wk) - S(wj,0) + S(wj,wk)) / (wj*wk)
;;
;; and fixing the lag d = b-a makes S(a,a+d) a sliding-window sum, so one
;; prefix-sum pass per lag gives every entry. That is O(n*p) work, not the
;; O(n*p^2) a general Gram matrix costs, and X is never formed.
;;
;; Second, the solver keeps c = X^T r rather than the residual r itself,
;; so each coordinate step is O(p) and does not touch the n observations.
;; That part is not specific to this design: the sweeps (cov-descend,
;; enet-descend, mt-descend) are lasso-cov.scm, taken here by include,
;; and only the three builders below know about the moving averages.
;;
;; Everything after the preparation is therefore independent of n.

(include "lasso-cov.scm")

;; S(a,b) for every pair, as a flat (wmax+1)^2 array. One pass per lag.
(define (build-S ps s q cs n nobs wmax)
  (do ((d (- 0 wmax) (+ d 1)))
      ((= d (+ wmax 1)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! q i 0.0))
    (if (< d 0)
        (do ((i 0 (+ i 1))) ((= i (+ n d)))
          (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d)))))
        (do ((i d (+ i 1))) ((= i n))
          (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d))))))
    (vector-set! cs 0 0.0)
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
    (do ((a 0 (+ a 1)))
        ((= a (+ wmax 1)))
      (let ((b (+ a d)))
        (if (< b 0)
            0
            (if (> b wmax)
                0
                (let ((m (- wmax a)))
                  (vector-set! s (+ (* a (+ wmax 1)) b)
                               (- (vector-ref cs (+ m nobs))
                                  (vector-ref cs m)))))))))
  0)

;; P(k) = sum_row ps[wmax+row-k] * y[row], for c = X^T y.
(define (build-P ps y pv nobs wmax)
  (do ((k 0 (+ k 1)))
      ((= k (+ wmax 1)))
    (let ((acc 0.0))
      (do ((r 0 (+ r 1))) ((= r nobs))
        (set! acc (+ acc (* (vector-ref ps (- (+ wmax r) k))
                            (vector-ref y r)))))
      (vector-set! pv k acc)))
  0)

(define (build-G s pv g c wmax p)
  (let ((s00 (vector-ref s 0)))
    (do ((j 0 (+ j 1)))
        ((= j p))
      (let ((wj (+ j 1)))
        (do ((k 0 (+ k 1)))
            ((= k p))
          (let ((wk (+ k 1)))
            (vector-set! g (+ (* j p) k)
                         (/ (- (+ s00 (vector-ref s (+ (* wj (+ wmax 1)) wk)))
                               (+ (vector-ref s wk)
                                  (vector-ref s (* wj (+ wmax 1)))))
                            (* wj wk)))))
        (vector-set! c j (/ (- (vector-ref pv 0) (vector-ref pv wj)) wj)))))
  0)

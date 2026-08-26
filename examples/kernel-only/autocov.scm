;; Autocovariances at every lag 0..p, by direct summation.
;;
;; r_k = sum_i x[i] * x[i+k] is the lag family of the series with
;; itself -- the diagonal of the family build-S tabulates for the
;; moving-average Gram matrix -- and p+1 direct sums cost O(n p),
;; which for p much smaller than n is the right tool (an FFT gives
;; all n lags in O(n log n), most of them unwanted).  The caller
;; subtracts the mean first if a covariance rather than a raw moment
;; is meant; the sums here are exactly what is written, in order,
;; so the result is deterministic bit for bit.
;;
;; R must have p+1 entries.  The Yule-Walker equations read the
;; result as both their Toeplitz matrix and their right-hand side:
;; every entry of X'X for the lagged design collapses onto these
;; p+1 numbers, which is the same collapse the moving-average Gram
;; matrix rides in lasso-cov.scm.

(define (autocov x r n p)
  (do ((k 0 (+ k 1)))
      ((> k p))
    (let ((acc 0.0))
      (do ((i 0 (+ i 1)))
          ((= i (- n k)))
        (set! acc (+ acc (* (vector-ref x i)
                            (vector-ref x (+ i k))))))
      (vector-set! r k acc)))
  0)

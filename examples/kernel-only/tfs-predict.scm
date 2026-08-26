;; Prediction for a moving-average design, without the design.
;;
;; The fitted values are X beta, and column j of X is the mean of the
;; last j+1 observations -- so a row of X beta is a sum of window means
;; read straight off the series' prefix sums.  Forming X to multiply by
;; it would cost O(n p) space and a pass over all of it; this costs
;; nothing but the coefficients that are not zero, which after a lasso
;; fit is most of the point: the sum skips every window the penalty
;; already dropped, exactly, so a sparse solution predicts in time
;; proportional to its own support rather than to p.
;;
;; PS is the inclusive prefix sum of the base series, BETA the p
;; coefficients, YHAT the NOBS fitted values.  Row r reads the window
;; ending at WMAX + r, so every index stays inside PS.

(define (tfs-predict ps beta yhat nobs wmax p)
  (do ((r 0 (+ r 1)))
      ((= r nobs))
    (let ((acc 0.0)
          (t (+ wmax r)))
      (do ((j 0 (+ j 1)))
          ((= j p))
        (let ((b (vector-ref beta j)))
          (if (= b 0.0)
              0
              (let ((w (+ j 1)))
                (set! acc (+ acc (* b (/ (- (vector-ref ps t)
                                            (vector-ref ps (- t w)))
                                         (* 1.0 w)))))))))
      (vector-set! yhat r acc)))
  0)

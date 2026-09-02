;;;; The elastic net in residual form: lasso-kernel.scm with the L1
;;;; share of the penalty in the threshold and the L2 share added to
;;;; the denominator of the step.  LAM1 = alpha * l1_ratio and
;;;; LAM2 = alpha * (1 - l1_ratio) in scikit-learn's parametrization
;;;; (fit_intercept=false), both scaled by N here.  With LAM2 = 0 every
;;;; operation is that of the lasso kernel.
;;;;
;;;; This is the form before the covariance update was written by hand
;;;; into enet-descend of lasso-cov.scm: --derive derives that form
;;;; from this one (the step's denominator is carried along untouched,
;;;; so the L2 share rides along).

(include "soft-threshold.scm")

(define (enet x beta resid xnorm lam1 lam2 iters n p)
  ;; The shapes, for --derive: X is p rows of n, the rest are vectors.
  (with-arrays ((x (p n)) (resid (n)) (beta (p)) (xnorm (p)))
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1))) ((or (= sweep iters) (= stop 1)))
      (let ((moved 0))
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((rho 0.0)
                (old (vector-ref beta j)))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                  (vector-ref resid i)))))
            (set! rho (+ rho (* old (vector-ref xnorm j))))
            (let ((bnew (/ (soft-threshold rho (* lam1 (* 1.0 n)))
                           (+ (vector-ref xnorm j) (* lam2 (* 1.0 n))))))
              (vector-set! beta j bnew)
              (if (not (= bnew old))
                  (begin
                    (set! moved 1)
                    (do ((i 0 (+ i 1))) ((= i n))
                      (vector-set! resid i
                                   (- (vector-ref resid i)
                                      (* (vector-ref x (+ (* j n) i))
                                         (- bnew old))))))
                  #f))))
        (if (= moved 0) (set! stop 1) 0)))))
  0)

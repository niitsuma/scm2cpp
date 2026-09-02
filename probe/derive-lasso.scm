;; The lasso kernel called on small dyadic data: two penalties, warm
;; started, the coefficient path and the final residual printed.  The
;; suite translates this plainly and with --derive -- the second run
;; replaces the residual sweeps by the covariance form the array
;; algebra derives from the kernel as written -- and both must print
;; what Racket prints.  The data are integers over powers of two so the
;; two arithmetic orders agree to the last digit.
(include "../examples/kernel-only/lasso-kernel.scm")

(define (main)
  (let ((n 4) (p 3) (nlam 2)
        (x (vector 1.0 2.0 0.0 -1.0
                   0.5 -0.5 1.0 0.25
                   0.0 1.0 -2.0 0.5))
        (y (vector 1.0 -1.0 2.0 0.5))
        (beta (make-vector 3 0.0))
        (resid (make-vector 4 0.0))
        (xnorm (make-vector 3 0.0))
        (lams (vector 0.25 0.0625))
        (betas (make-vector 6 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* j n) i))
                              (vector-ref x (+ (* j n) i))))))
        (vector-set! xnorm j acc)))
    (lasso x beta resid xnorm lams betas 20 n p nlam)
    (do ((t 0 (+ t 1))) ((= t 6))
      (display (vector-ref betas t)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

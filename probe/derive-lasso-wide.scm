;; The lasso kernel of derive-lasso.scm on a wide X: three
;; coefficients, two observations.  --derive puts the derived Gram form
;; under (if (< p n) ..) and keeps the sweep as written in the else
;; branch, as scikit-learn's precompute='auto' chooses; here p > n, so
;; the derived translation must take the original sweep and print what
;; Racket prints.  The data are dyadic, as in derive-lasso.scm.
(include "../examples/kernel-only/lasso-kernel.scm")

(define (main)
  (let ((n 2) (p 3) (nlam 2)
        (x (vector 1.0 2.0 0.5 -0.5 0.0 1.0))
        (y (vector 1.0 -1.0))
        (beta (make-vector 3 0.0))
        (resid (make-vector 2 0.0))
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
    (lasso x beta resid xnorm lams betas 20 0.0 n p nlam)
    (do ((t 0 (+ t 1))) ((= t 6))
      (display (vector-ref betas t)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

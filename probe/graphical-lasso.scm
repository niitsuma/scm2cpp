;; graphical-lasso.scm on a 5 x 5 empirical covariance (a tridiagonal
;; precision's covariance, rounded to dyadic entries), alpha 0.1:
;; translated plainly and with --blas (its two matrix-vector products as
;; dgemv) against the same oracle.  Prints the iteration count, the
;; precision and the covariance.
(include "../examples/kernel-only/graphical-lasso.scm")

(define (main)
  (let ((p 5)
        (emp (vector 1.0 0.5 0.25 0.125 0.0625
                     0.5 1.0 0.5 0.25 0.125
                     0.25 0.5 1.0 0.5 0.25
                     0.125 0.25 0.5 1.0 0.5
                     0.0625 0.125 0.25 0.5 1.0))
        (cov (make-vector 25 0.0))
        (prec (make-vector 25 0.0)))
    (let ((it (graphical-lasso emp cov prec 0.1 100 1e-6 1e-6 p)))
      (display it) (newline)
      (do ((i 0 (+ i 1))) ((= i 25))
        (display (vector-ref prec i)) (display " "))
      (newline)
      (do ((i 0 (+ i 1))) ((= i 25))
        (display (vector-ref cov i)) (display " "))
      (newline))
    0))

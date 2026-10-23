;; lasso-design.scm on the data of derive-lasso.scm: X in C order
;; (4 rows of 3), y as is, the residual and the column norms left to
;; the kernel.  Plainly and with --derive (and --blas, --cublas) it
;; must print what derive-lasso.scm prints -- the same coefficients
;; and the same restored residual -- so the fills inside the kernel
;; (residual from y, norms from the columns) survive the derivation,
;; or are folded into it, without moving a digit.  The first line is
;; the kernel's value, the sweeps it ran, which the derivation must
;; keep too (DesignLasso's n_iter_).
(include "../examples/kernel-only/lasso-design.scm")

(define (main)
  (let ((n 4) (p 3) (nlam 2)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5))
        (y (vector 1.0 -1.0 2.0 0.5))
        (resid (make-vector 4 0.0))
        (xnorm (make-vector 3 0.0))
        (beta (make-vector 3 0.0))
        (lams (vector 0.25 0.0625))
        (betas (make-vector 6 0.0)))
    (display (lasso-design x y resid xnorm beta lams betas 20 0.0 n p nlam))
    (newline)
    (do ((t 0 (+ t 1))) ((= t 6))
      (display (vector-ref betas t)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

;; svm-kernel.scm on small dyadic data: 6 observations of 3 features,
;; labels +-1, C = 0.5.  Translated plainly and with --derive (and
;; --blas, --cublas) by the suite, each must print what Racket prints:
;; the dual variables and the primal vector.  With --derive the sweep
;; runs over the memo c = X w and the kernel matrix X X', under the
;; guard (if (< n p) ..) -- here n > p, so the derived translation
;; takes the primal sweep as written; derive-svm-wide.scm is the other
;; branch.
(include "../examples/kernel-only/svm-kernel.scm")

(define (main)
  (let ((n 6) (p 3)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5
                   0.5 -1.0 0.75
                   -0.25 0.5 -1.0))
        (y (vector 1.0 1.0 -1.0 -1.0 1.0 -1.0))
        (w (make-vector 3 0.0))
        (alpha (make-vector 6 0.0))
        (xnorm (make-vector 6 0.0)))
    (svm x y w alpha xnorm 0.5 30 0.0 n p)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref alpha i)) (display " "))
    (newline)
    (do ((j 0 (+ j 1))) ((= j p))
      (display (vector-ref w j)) (display " "))
    (newline)
    0))

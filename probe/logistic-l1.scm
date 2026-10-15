;; logistic-l1.scm, liblinear's L1-regularized logistic regression
;; whole (newGLMNET), on twelve points in three features stored by
;; columns as liblinear holds them.  Prints the Newton iteration count
;; and the coefficients; the oracle runs the same program, exp and log
;; included.
(include "../examples/kernel-only/logistic-l1.scm")

(define (main)
  (let ((n 12) (p 3)
        ;; column j is x[j*n .. j*n+n-1]
        (x (vector 1.0 0.5 -1.0 2.0 -0.5 0.25 1.5 -2.0 0.75 -1.25 0.0 1.0
                   0.5 -1.0 0.25 0.0 1.5 -0.75 -0.5 1.0 2.0 -1.5 0.25 -0.25
                   -0.25 0.75 1.0 -1.5 0.5 0.0 1.25 -0.5 -1.0 0.5 2.0 -0.75))
        (y (vector 1.0 1.0 -1.0 1.0 -1.0 1.0 1.0 -1.0 1.0 -1.0 1.0 -1.0))
        (w (make-vector 3 0.0)))
    (let ((it (logistic-l1 x y w 2.0 1e-6 100 1 n p)))
      (display it) (newline)
      (do ((j 0 (+ j 1))) ((= j p))
        (display (vector-ref w j)) (display " "))
      (newline))
    0))

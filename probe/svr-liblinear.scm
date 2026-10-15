;; svr-liblinear.scm, liblinear's linear epsilon-SVR with the L1 loss
;; whole, on eight points in three features (n rows of p).  Prints the
;; sweep count and the weights; the oracle runs the same program.
(include "../examples/kernel-only/svr-liblinear.scm")

(define (main)
  (let ((n 8) (p 3)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5
                   0.5 -1.0 0.75
                   -0.25 0.5 -1.0
                   1.5 1.0 -0.5
                   -0.75 -0.25 1.0))
        (y (vector 1.25 2.5 -1.5 -0.75 1.0 -0.5 1.75 -1.25))
        (w (make-vector 3 0.0))
        (beta (make-vector 8 0.0))
        (xnorm (make-vector 8 0.0)))
    (let ((it (svr-liblinear x y w beta xnorm 1.0 0.25 1000 1e-6 7 n p)))
      (display it) (newline)
      (do ((j 0 (+ j 1))) ((= j p))
        (display (vector-ref w j)) (display " "))
      (newline))
    0))

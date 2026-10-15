;; svr-smo, epsilon-SVR by libsvm's SMO (svm-smo.scm, the same solver
;; as C-SVC over 2n variables), on the data of svr-liblinear.scm with
;; the linear kernel K = X X' built here.  Prints the iteration count,
;; the coefficients alpha - alpha* and the bias rho; the oracle runs
;; the same program.
(include "../examples/kernel-only/svm-smo.scm")

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
        (z (vector 1.25 2.5 -1.5 -0.75 1.0 -0.5 1.75 -1.25))
        (k (make-vector 64 0.0))
        (beta (make-vector 8 0.0))
        (rho (make-vector 1 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j n))
        (let ((acc 0.0))
          (do ((l 0 (+ l 1))) ((= l p))
            (set! acc (+ acc (* (vector-ref x (+ (* i p) l))
                                (vector-ref x (+ (* j p) l))))))
          (vector-set! k (+ (* i n) j) acc))))
    (let ((it (svr-smo k z beta rho 1.0 0.25 1000 1e-6 n)))
      (display it) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref beta i)) (display " "))
      (newline)
      (display (vector-ref rho 0)) (newline))
    0))

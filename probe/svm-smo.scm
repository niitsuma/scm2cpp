;; svm-smo.scm, libsvm's SMO solver whole, on the data of
;; derive-svm.scm with two more points, the linear kernel K = X X'
;; built here.  Prints the iteration count, the alphas and the bias
;; rho; the oracle runs the same program, and SVC(kernel='precomputed',
;; C=0.5, tol=1e-6) gives the same alphas and rho to every printed
;; digit.  It converges in 6 iterations, before the first shrinking
;; step (n iterations in): bench/svm-compare.py is where that runs.
;; The last line is the RBF kernel of the same points (gamma 1/2) by
;; rbf-from-products: one entry and the sum of all 64.
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
        (y (vector 1.0 1.0 -1.0 -1.0 1.0 -1.0 1.0 -1.0))
        (k (make-vector 64 0.0))
        (alpha (make-vector 8 0.0))
        (rho (make-vector 1 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j n))
        (let ((acc 0.0))
          (do ((l 0 (+ l 1))) ((= l p))
            (set! acc (+ acc (* (vector-ref x (+ (* i p) l))
                                (vector-ref x (+ (* j p) l))))))
          (vector-set! k (+ (* i n) j) acc))))
    (let ((it (svm-smo k y alpha rho 0.5 1000 1e-6 n)))
      (display it) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref alpha i)) (display " "))
      (newline)
      (display (vector-ref rho 0)) (newline))
    ;; the RBF kernel from the same products (k is X X'), gamma 1/2
    (let ((sq (make-vector 8 0.0)) (tot 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! sq i (vector-ref k (+ (* i n) i))))
      (rbf-from-products k sq sq 0.5 n n)
      (do ((t 0 (+ t 1))) ((= t 64))
        (set! tot (+ tot (vector-ref k t))))
      (display (vector-ref k 1)) (display " ") (display tot) (newline))
    0))

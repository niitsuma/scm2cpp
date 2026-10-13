;; mt3-kernel.scm on small dyadic data: 2 blocks of 2 tasks over the
;; 4 x 3 design of derive-mt-col.scm, the residual a 4 x 2 x 2 array.
;; Translated plainly and with --derive (and --blas, --cublas) by the
;; suite, each must print what Racket prints: the derivation's memo is
;; 2 x 2 x 3, its restoration walks W flattened to 3 x 4, and the
;; whole-array products stand in nested scopes that redeclare the
;; rank-3 names as the matrices they flatten to.
(include "../examples/kernel-only/mt3-kernel.scm")

(define (main)
  (let ((n 4) (p 3) (nb 2) (nt 2)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5))
        ;; y[i,b,t]: row i holds the four tasks (b,t) in C order
        (y (vector 1.0 0.5 -0.5 2.0
                   -1.0 1.0 0.25 -2.0
                   2.0 -1.0 1.5 0.5
                   0.5 2.0 -1.0 1.0))
        (w (make-vector 12 0.0))
        (resid (make-vector 16 0.0))
        (xnorm (make-vector 3 0.0)))
    (do ((i 0 (+ i 1))) ((= i (* n (* nb nt))))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                              (vector-ref x (+ (* i p) j))))))
        (vector-set! xnorm j acc)))
    (mt3 x w resid xnorm 0.0625 0.125 20 n p nb nt)
    (do ((k 0 (+ k 1))) ((= k 12))
      (display (vector-ref w k)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 16))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

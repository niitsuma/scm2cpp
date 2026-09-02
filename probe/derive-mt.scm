;; The multi-task lasso kernel on small dyadic data, translated plainly
;; and with --derive by the suite; both must print what Racket prints.
;; The residual is a matrix (one row per task) updated a row at a time,
;; so the derivation's memo is ntask by p and the restoration walks the
;; coefficient matrix.
(include "../examples/kernel-only/mt-kernel.scm")

(define (main)
  (let ((n 4) (p 3) (ntask 2)
        (x (vector 1.0 2.0 0.0 -1.0
                   0.5 -0.5 1.0 0.25
                   0.0 1.0 -2.0 0.5))
        (y (vector 1.0 -1.0 2.0 0.5
                   0.5 1.0 -1.0 2.0))
        (w (make-vector 6 0.0))
        (resid (make-vector 8 0.0))
        (xnorm (make-vector 3 0.0)))
    (do ((i 0 (+ i 1))) ((= i (* ntask n)))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* j n) i))
                              (vector-ref x (+ (* j n) i))))))
        (vector-set! xnorm j acc)))
    (mt x w resid xnorm 0.0625 0.125 20 n p ntask)
    (do ((k 0 (+ k 1))) ((= k (* p ntask)))
      (display (vector-ref w k)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i (* ntask n)))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

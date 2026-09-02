;; The elastic-net kernel on small dyadic data, translated plainly and
;; with --derive by the suite; both must print what Racket prints.  The
;; kernel's sweep sits under a (let ((stop 0)) ..), which the derivation
;; enters, so the Gram matrix is built once in front of the sweep loop.
(include "../examples/kernel-only/enet-kernel.scm")

(define (main)
  (let ((n 4) (p 3)
        (x (vector 1.0 2.0 0.0 -1.0
                   0.5 -0.5 1.0 0.25
                   0.0 1.0 -2.0 0.5))
        (y (vector 1.0 -1.0 2.0 0.5))
        (beta (make-vector 3 0.0))
        (resid (make-vector 4 0.0))
        (xnorm (make-vector 3 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* j n) i))
                              (vector-ref x (+ (* j n) i))))))
        (vector-set! xnorm j acc)))
    (enet x beta resid xnorm 0.0625 0.125 20 n p)
    (do ((j 0 (+ j 1))) ((= j p))
      (display (vector-ref beta j)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

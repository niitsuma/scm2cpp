;; fastica.scm on sixteen points mixing two sources (a square wave and a
;; ramp), the start a fixed 2 x 2 matrix.  Translated plainly and with
;; --blas; the oracle runs the same program.
;; Prints the iterations, the components, the whitening and the mean.
(include "../examples/kernel-only/fastica.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 16) (p 2) (nc 2)
        (x (vector 1.5 0.25  -0.5 1.25  1.75 0.5  -0.25 1.5  2.0 0.75  0.0 1.75
                   2.25 1.0  0.25 2.0  0.5 -1.0  -1.5 0.0  0.75 -0.75  -1.25 0.25
                   1.0 -0.5  -1.0 0.5  1.25 -0.25  -0.75 0.75))
        (winit (vector 0.5 -1.25 1.0 0.75))
        (z 0))
    ;; one kind of vector for the results: runtime-sized
    (let ((unmix (make-vector (* nc nc) 0.0))
          (comps (make-vector (* nc p) 0.0))
          (white (make-vector (* nc p) 0.0))
          (mean (make-vector p 0.0)))
    (display (fastica x winit comps white unmix mean 200 0.0001 n p nc)) (newline)
    (show comps 4)
    (show white 4)
    (show mean 2)
    0)))

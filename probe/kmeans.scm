;; kmeans.scm on ten points in the plane, three centres started from
;; three of the points, tiles of 4 points: translated plainly and with
;; --blas against the same oracle.  The data are centred on their mean
;; (as scikit-learn centres them) so the digits are dyadic.  Prints the
;; iteration count, the labels, the centres and the inertia.
(include "../examples/kernel-only/kmeans.scm")

(define (main)
  (let ((n 10) (p 2) (k 3)
        (x (vector -2.0 -2.0  -1.5 -2.0  -2.0 -1.5
                   1.0 1.0  1.5 1.0  1.0 1.5  1.5 1.5
                   -1.0 2.0  0.0 2.0  1.0 -2.5))
        (centers (vector -2.0 -2.0  1.0 1.0  0.0 2.0))
        (labels (make-vector 10 0.0))
        (out (make-vector 1 0.0)))
    (let ((it (kmeans x centers labels out 100 0.0 4 n p k)))
      (display it) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref labels i)) (display " "))
      (newline)
      (do ((i 0 (+ i 1))) ((= i 6))
        (display (vector-ref centers i)) (display " "))
      (newline)
      (display (vector-ref out 0)) (newline))
    0))

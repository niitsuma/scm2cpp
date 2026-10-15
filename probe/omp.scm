;; omp.scm on twelve points in four features (centred by hand), two
;; columns selected: translated plainly and with --blas (X'X and X'y as
;; dsyrk and dgemv) against the same oracle, the path recorded.  Prints
;; the count, the coefficients and the path's rows.
(include "../examples/kernel-only/omp.scm")

(define (main)
  (let ((n 12) (p 4)
        (x (vector 1.0 0.5 -0.5 0.0   -1.0 0.5 0.5 1.0   0.5 -1.0 1.0 -0.5
                   -0.5 -0.5 -1.0 0.5   1.5 1.0 0.0 -1.0   -1.5 0.0 0.5 0.5
                   0.0 1.5 -0.5 -1.5   0.5 -1.5 1.0 1.0   -1.0 1.0 -0.5 0.0
                   1.0 -0.5 0.0 0.5   -0.5 -1.0 -1.0 -0.5   0.0 0.0 0.5 0.0))
        (y (vector 2.0 -1.5 0.5 -1.0 3.0 -2.5 1.0 -0.5 -1.5 1.5 -1.0 0.0))
        (coef (make-vector 4 0.0))
        (path (make-vector 8 0.0)))
    (let ((k (omp x y coef path 1 2 n p)))
      (display k) (newline)
      (do ((j 0 (+ j 1))) ((= j p))
        (display (vector-ref coef j)) (display " "))
      (newline)
      (do ((s 0 (+ s 1))) ((= s k))
        (do ((j 0 (+ j 1))) ((= j p))
          (display (vector-ref path (+ (* s p) j))) (display " "))
        (newline)))
    0))

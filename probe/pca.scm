;; pca.scm on ten points in three features (sym-eigen.scm's Householder
;; reduction and QL iteration).  Translated plainly and with --blas; the
;; oracle runs the same program.  Prints the components (signed as
;; svd_flip signs them), the explained variances, the singular values
;; and the mean.
(include "../examples/kernel-only/pca.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 10) (p 3)
        (x (vector 2.5 2.4 0.5  0.5 0.7 -1.0  2.2 2.9 0.25  1.9 2.2 1.5  3.1 3.0 -0.5
                   2.3 2.7 0.75  2.0 1.6 -1.25  1.0 1.1 2.0  1.5 1.6 -0.75  1.1 0.9 1.0))
        (z 0))
    ;; one kind of vector for the results: runtime-sized
    (let ((comps (make-vector (* p p) 0.0))
          (ev (make-vector p 0.0))
          (sv (make-vector p 0.0))
          (mean (make-vector p 0.0)))
    (pca x comps ev sv mean n p)
    (show comps 9)
    (show ev 3)
    (show sv 3)
    (show mean 3)
    0)))

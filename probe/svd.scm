;; sym-svd.scm on a tall (4 x 3) and a wide (2 x 3) matrix.  Prints
;; the singular values, the product U diag(S) Vt (which must give the
;; matrix back, whatever the signs), and 1 + U'U's off-diagonal entry
;; (the left vectors orthogonal).  Plain it is the one-sided Jacobi;
;; under --blas the same call is LAPACK's dgesdd.
(include "../examples/kernel-only/sym-svd.scm")

(define (show-svd a0 m n)
  (let ((k (if (< m n) m n)))
    (let ((a (make-vector (* m n) 0.0))
          (u (make-vector (* m k) 0.0))
          (s (make-vector k 0.0))
          (vt (make-vector (* k n) 0.0)))
      (do ((t 0 (+ t 1))) ((= t (* m n))) (vector-set! a t (vector-ref a0 t)))
      (sym-svd a u s vt m n)
      (do ((j 0 (+ j 1))) ((= j k)) (display (vector-ref s j)) (display " "))
      (newline)
      (do ((i 0 (+ i 1))) ((= i m))
        (do ((j 0 (+ j 1))) ((= j n))
          (let ((acc 0.0))
            (do ((l 0 (+ l 1))) ((= l k))
              (set! acc (+ acc (* (vector-ref u (+ (* i k) l))
                                  (* (vector-ref s l) (vector-ref vt (+ (* l n) j)))))))
            (display acc) (display " "))))
      (newline)
      (let ((d 0.0))
        (do ((i 0 (+ i 1))) ((= i m))
          (set! d (+ d (* (vector-ref u (* i k)) (vector-ref u (+ (* i k) 1))))))
        (display (+ 1.0 d)) (newline))
      0)))

(define (main)
  (show-svd (vector 1.0 0.5 2.0
                    2.0 -0.5 1.0
                    0.25 1.0 -2.0
                    -1.0 0.25 0.5)
            4 3)
  ;; padded to the tall one's twelve entries: a vector literal's size
  ;; is its C++ type, and show-svd takes one type
  (show-svd (vector 1.5 -0.5 0.75
                    0.5 2.0 -1.25
                    0.0 0.0 0.0 0.0 0.0 0.0)
            2 3)
  0)

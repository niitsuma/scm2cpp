;; truncated-svd.scm on a tall (7 x 3) and a wide (3 x 5) matrix, two
;; components each: the singular values, the right vectors and the
;; transformed data (svd_flip's signs make both determined); then
;; gram.scm's gram-ridge-solve, (G + 0.5 I) W = C for G = X'X of the tall
;; one and two right-hand sides, and tsvd-gram on that G.  Each value
;; printed plus one, so that what rounds to zero prints alike.  Plain
;; the eigenproblems and the Cholesky are the subset's; under --blas
;; dsyevr and dposv.
(include "../examples/kernel-only/truncated-svd.scm")
(include "../examples/kernel-only/gram.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (+ 1.0 (vector-ref v j))) (display " "))
  (newline))

(define (run x n p wide)
  (let ((k 2))
    (let ((v (make-vector (* p k) 0.0))
          (s (make-vector k 0.0))
          (z (make-vector (* n k) 0.0)))
      (if (= wide 1) (tsvd-wide x v s z n p k) (tsvd-tall x v s z n p k))
      (show s k)
      (show v (* p k))
      (show z (* n k))
      0)))

(define (main)
  (let ((x (vector 0.31 -0.72 1.05  0.18 -0.44 0.93  0.67 -1.21 -0.09  0.52 1.38 -0.35
                   -0.81 -0.27 0.44  1.12 0.05 -0.63  -0.38 0.91 0.27))
        (w (vector 1.2 -0.4 0.7 0.3 -0.9  0.5 1.1 -0.6 0.8 0.2  -0.3 0.6 1.4 -0.5 0.9
                   0.0 0.0 0.0 0.0 0.0 0.0))
        (g (make-vector 9 0.0))
        (c (make-vector 6 0.0)))
    (run x 7 3 0)
    ;; the wide one padded to the tall one's 21 entries: one vector type
    (run w 3 5 1)
    (with-arrays ((x (7 3)) (g (3 3)))
      (array-set! g (matmul (transpose x) x)))
    (vector-set! c 0 1.5) (vector-set! c 1 -0.5) (vector-set! c 2 0.25)
    (vector-set! c 3 2.0) (vector-set! c 4 -1.0) (vector-set! c 5 0.75)
    (display (gram-ridge-solve g c 0.5 3 2)) (newline)
    (show c 6)
    ;; tsvd-gram on the same G (gram-ridge-solve copied it): the tall
    ;; one's singular values again (its vectors' signs are not fixed)
    (let ((v2 (make-vector 6 0.0)) (s2 (make-vector 2 0.0)))
      (tsvd-gram g v2 s2 3 2)
      (show s2 2))
    0))

;; The whole-array products of the array algebra, written by hand:
;; every shape (matmul ...) expands, and the matrix-expression forms
;; beside them.  Translated plainly, the products are loop nests; with
;; --blas or --cublas each becomes one call of the binding's op
;; (rewrite-blas.scm), and all three must print what Racket prints.
;; Dyadic data, so the summation orders agree to the last digit.
(define (products a b v g h c r s d n p q)
  (with-arrays ((a (p n)) (b (q n)) (v (n)) (g (p p)) (h (p q))
                (c (p)) (r (n)) (s (q n)) (d (p q)))
    (array-set! g (matmul a (transpose a)))    ; gram
    (array-set! h (matmul a (transpose b)))    ; a b^T
    (array-set! c (matmul a v))                ; a v
    (array-set! r (matmul (transpose a) c))    ; a^T c  (= zero-fill, then rows)
    (array-dec! r (matmul (transpose a) (- c (scale 0.5 c))))
    (array-set! d (- (scale 0.25 h) h))        ; whole-matrix =
    (array-inc! d h)                           ; whole-matrix +=
    (array-set! s (matmul (transpose d) a))    ; d^T a, a matrix expression below
    (array-dec! s (matmul (transpose (scale 0.5 d)) a))
    0))

(define (main)
  (let ((n 4) (p 3) (q 2)
        (a (vector 1.0 2.0 0.0 -1.0
                   0.5 -0.5 1.0 0.25
                   0.0 1.0 -2.0 0.5))
        (b (vector 2.0 0.0 -1.0 1.0
                   0.5 1.0 0.5 -2.0))
        (v (vector 1.0 -1.0 2.0 0.5))
        (g (make-vector 9 0.0))
        (h (make-vector 6 0.0))
        (c (make-vector 3 0.0))
        (r (make-vector 4 0.0))
        (s (make-vector 8 0.0))
        (d (make-vector 6 0.0)))
    (products a b v g h c r s d n p q)
    (do ((i 0 (+ i 1))) ((= i 9)) (display (vector-ref g i)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 6)) (display (vector-ref h i)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 3)) (display (vector-ref c i)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 4)) (display (vector-ref r i)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 8)) (display (vector-ref s i)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i 6)) (display (vector-ref d i)) (display " "))
    (newline)
    0))

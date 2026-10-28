;;;; The K leading singular triplets of a dense X (n x p) through the
;;;; Gram matrix: scikit-learn's TruncatedSVD, written out in the subset.
;;;;
;;;; Tall (n >= p): X'X = V diag(s^2) V', its K largest pairs by
;;;; sym-eigen-top (dsyevr under --blas, X'X by dsyrk), and the
;;;; transformed data Z = X V = U diag(s) by one dgemm.  Wide: X X' =
;;;; U diag(s^2) U' instead, Z = U diag(s), V' = diag(1/s) U'X.  Either
;;;; way the signs are svd_flip's with u_based_decision=False: each
;;;; right vector's entry of largest magnitude positive.  The answer is
;;;; the exact one, where scikit-learn's default randomized solver
;;;; approximates it; the Gram squares the condition, so the smaller
;;;; of the K values carry about eps * s_1^2 / s_k of absolute error.
;;;;

(include "sym-eigen.scm")

;; Column R of V (p x K) and of Z (n x K) negated when V's entry of
;; largest magnitude in that column is negative
(define (tsvd-flip v z n p k)
  (do ((r 0 (+ r 1))) ((= r k))
    (let ((big 0) (bv -1.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((a (vector-ref v (+ (* j k) r))))
          (let ((aa (if (< a 0.0) (- 0.0 a) a)))
            (if (> aa bv) (begin (set! bv aa) (set! big j)) 0))))
      (if (< (vector-ref v (+ (* big k) r)) 0.0)
          (begin
            (do ((j 0 (+ j 1))) ((= j p))
              (vector-set! v (+ (* j k) r) (- 0.0 (vector-ref v (+ (* j k) r)))))
            (do ((i 0 (+ i 1))) ((= i n))
              (vector-set! z (+ (* i k) r) (- 0.0 (vector-ref z (+ (* i k) r))))))
          0)))
  0)

;; Tall: V (p x K) the right vectors as columns, S the values
;; (decreasing), Z (n x K) = X V
(define (tsvd-tall x v s z n p k)
  (let ((g (make-vector (* p p) 0.0))
        (e (make-vector p 0.0)))
    (with-arrays ((x (n p)) (g (p p)))
      (array-set! g (matmul (transpose x) x)))
    (sym-eigen-top g v s e p k)
    (do ((r 0 (+ r 1))) ((= r k))
      (vector-set! s r (if (> (vector-ref s r) 0.0) (sqrt (vector-ref s r)) 0.0)))
    (with-arrays ((x (n p)) (v (p k)) (z (n k)))
      (array-set! z (matmul x v)))
    (tsvd-flip v z n p k)
    0))

;; Wide: the same from X X' (n x n); U (n x K) its vectors, Z = U diag(s),
;; V (p x K) = X'U diag(1/s) (zero where s is)
(define (tsvd-wide x v s z n p k)
  (let ((g (make-vector (* n n) 0.0))
        (u (make-vector (* n k) 0.0))
        (e (make-vector n 0.0)))
    (with-arrays ((x (n p)) (g (n n)))
      (array-set! g (matmul x (transpose x))))
    (sym-eigen-top g u s e n k)
    (do ((r 0 (+ r 1))) ((= r k))
      (vector-set! s r (if (> (vector-ref s r) 0.0) (sqrt (vector-ref s r)) 0.0)))
    (with-arrays ((x (n p)) (u (n k)) (v (p k)))
      (array-set! v (matmul (transpose x) u)))
    (do ((j 0 (+ j 1))) ((= j p))
      (do ((r 0 (+ r 1))) ((= r k))
        (let ((sr (vector-ref s r)))
          (vector-set! v (+ (* j k) r) (if (> sr 0.0) (/ (vector-ref v (+ (* j k) r)) sr) 0.0)))))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((r 0 (+ r 1))) ((= r k))
        (vector-set! z (+ (* i k) r) (* (vector-ref u (+ (* i k) r)) (vector-ref s r)))))
    (tsvd-flip v z n p k)
    0))

;; A Gram matrix formed elsewhere (a sparse design's, by csr-gram): G
;; (m x m, destroyed) gives V (m x K) its leading vectors and S the
;; square roots of their values, decreasing (zero where negative)
(define (tsvd-gram g v s m k)
  (let ((e (make-vector m 0.0)))
    (sym-eigen-top g v s e m k)
    (do ((r 0 (+ r 1))) ((= r k))
      (vector-set! s r (if (> (vector-ref s r) 0.0) (sqrt (vector-ref s r)) 0.0)))
    0))

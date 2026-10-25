;; lda.scm on twelve points in three features, three classes: the class
;; means and counts, the within-class covariance from X'X, the svd
;; solver's singular values and its vectors as their squares, and the
;; eigen solver's two leading pairs of Sb v = lam Sw v (the values, the
;; vectors as their squares: V'SwV = I fixes the scale, not the sign).
;; Each value printed plus one, so that what rounds to zero prints alike.
;; Plain the eigenproblems are sym-eigen.scm's; under --blas dsyevd and
;; dsygvd.
(include "../examples/kernel-only/lda.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (+ 1.0 (vector-ref v j))) (display " "))
  (newline))

(define (squares v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (+ 1.0 (* (vector-ref v j) (vector-ref v j)))) (display " "))
  (newline))

(define (main)
  (let ((n 12) (p 3) (k 3))
    (let ((x (vector 0.31 -0.72 1.05  0.18 -0.44 0.93  0.67 -1.21 -0.09  0.52 1.38 -0.35
                     -0.81 -0.27 0.44  1.12 0.05 -0.63  -0.38 0.91 0.27  0.74 -0.16 1.41
                     -1.02 0.58 -0.47  0.29 1.17 0.83  -0.55 -0.93 0.12  0.96 0.36 -1.08))
          (lab (make-vector n 0))
          (g (make-vector (* p p) 0.0))
          (sw (make-vector (* p p) 0.0))
          (st (make-vector (* p p) 0.0))
          (means (make-vector (* k p) 0.0))
          (counts (make-vector k 0.0))
          (std (make-vector p 0.0))
          (v (make-vector (* p p) 0.0))
          (s (make-vector p 0.0))
          (ev (make-vector p 0.0))
          (xbar (make-vector p 0.0)))
      ;; classes 0 1 2 0 1 2 .., and class 2 shifted so the means differ
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! lab i (remainder i 3))
        (if (= (remainder i 3) 2)
            (vector-set! x (* i p) (+ (vector-ref x (* i p)) 1.5))
            0))
      (lda-moments x lab g means counts n p k)
      (show means (* k p))
      (show counts k)
      (lda-within g means counts n p k)
      (show g (* p p))
      (do ((q 0 (+ q 1))) ((= q (* p p))) (vector-set! sw q (vector-ref g q)))
      (lda-svd-first sw std v s p)
      (show std p)
      (show s p)
      (squares v (* p p))
      ;; St = Sw + sum_k (n_k / n) (mu_k - xbar)(mu_k - xbar)', Sb = St - Sw
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((acc 0.0))
          (do ((c 0 (+ c 1))) ((= c k))
            (set! acc (+ acc (* (vector-ref counts c) (vector-ref means (+ (* c p) j))))))
          (vector-set! xbar j (/ acc (exact->inexact n)))))
      (do ((a 0 (+ a 1))) ((= a p))
        (do ((b 0 (+ b 1))) ((= b p))
          (let ((acc 0.0))
            (do ((c 0 (+ c 1))) ((= c k))
              (set! acc (+ acc (* (/ (vector-ref counts c) (exact->inexact n))
                                  (* (- (vector-ref means (+ (* c p) a)) (vector-ref xbar a))
                                     (- (vector-ref means (+ (* c p) b)) (vector-ref xbar b)))))))
            (vector-set! st (+ (* a p) b) acc))))
      (do ((q 0 (+ q 1))) ((= q (* p p))) (vector-set! sw q (vector-ref g q)))
      (lda-eigen st sw v ev p)
      (show ev 2)
      (do ((j 0 (+ j 1))) ((= j p))
        (display (+ 1.0 (* (vector-ref v (* j p)) (vector-ref v (* j p))))) (display " ")
        (display (+ 1.0 (* (vector-ref v (+ (* j p) 1)) (vector-ref v (+ (* j p) 1))))) (display " "))
      (newline)
      0)))

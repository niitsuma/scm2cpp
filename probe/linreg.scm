;; linreg.scm on ten rows of three features and two targets: the
;; centred Gram and cross product formed here by loops, then the guarded
;; solve and the singular values; and a design whose third column is the
;; sum of the other two, which the guard refuses (0) and whose rank is 2.  Plain the
;; eigenproblems are sym-eigen.scm's; under --blas LAPACK's dsyevd.
(include "../examples/kernel-only/linreg.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

;; centred cross products of the columns of A (n x pa) and B (n x pb)
(define (cross a b c n pa pb)
  (let ((ma (make-vector pa 0.0)) (mb (make-vector pb 0.0)))
    (do ((j 0 (+ j 1))) ((= j pa))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! ma j (+ (vector-ref ma j) (/ (vector-ref a (+ (* i pa) j)) (* 1.0 n))))))
    (do ((j 0 (+ j 1))) ((= j pb))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! mb j (+ (vector-ref mb j) (/ (vector-ref b (+ (* i pb) j)) (* 1.0 n))))))
    (do ((r 0 (+ r 1))) ((= r pa))
      (do ((s 0 (+ s 1))) ((= s pb))
        (let ((acc 0.0))
          (do ((i 0 (+ i 1))) ((= i n))
            (set! acc (+ acc (* (- (vector-ref a (+ (* i pa) r)) (vector-ref ma r))
                                (- (vector-ref b (+ (* i pb) s)) (vector-ref mb s))))))
          (vector-set! c (+ (* r pb) s) acc))))
    0))

(define (run x y n p t)
  (let ((g (make-vector (* p p) 0.0)) (g2 (make-vector (* p p) 0.0))
        (b (make-vector (* p t) 0.0)) (coef (make-vector (* p t) 0.0))
        (s (make-vector p 0.0)))
    (cross x x g n p p)
    (cross x x g2 n p p)
    (cross x y b n p t)
    (display (linreg-solve g b coef p t 1e-6 1e-6)) (newline)
    (show coef (* p t))
    ;; the singular values up to the rank: below it is rounding
    (let ((r (linreg-singular g2 s p 1e-6)))
      (display r) (newline)
      (show s r))
    0))

(define (main)
  (let ((x0 (vector 0.31 -0.72 1.05  0.18 -0.44 0.93  0.67 -1.21 -0.09  0.52 1.38 -0.35
                    -0.81 -0.27 0.44  1.12 0.05 -0.63  -0.38 0.91 0.27  0.74 -0.16 1.41
                    -1.02 0.58 -0.47  0.29 1.17 0.83))
        (y0 (vector 0.4 -0.2  0.9 0.1  -0.3 0.7  0.2 -0.8  0.6 0.5
                    -0.7 0.3  0.1 0.9  -0.5 -0.4  0.8 -0.1  -0.2 0.6))
        (n 10) (p 3) (t 2))
    (let ((x (make-vector (* n p) 0.0)) (xd (make-vector (* n p) 0.0))
          (y (make-vector (* n t) 0.0)))
      (do ((s 0 (+ s 1))) ((= s (* n p))) (vector-set! x s (vector-ref x0 s)))
      (do ((s 0 (+ s 1))) ((= s (* n t))) (vector-set! y s (vector-ref y0 s)))
      ;; the dependent design: column 2 = column 0 + column 1
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! xd (* i p) (vector-ref x (* i p)))
        (vector-set! xd (+ (* i p) 1) (vector-ref x (+ (* i p) 1)))
        (vector-set! xd (+ (* i p) 2) (+ (vector-ref x (* i p)) (vector-ref x (+ (* i p) 1)))))
      (run x y n p t)
      (run xd y n p t)
      0)))

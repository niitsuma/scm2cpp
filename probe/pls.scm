;; pls.scm on ten rows of three features and two targets, two
;; components: PLSRegression (regression deflation, mode A), PLSCanonical
;; (canonical, mode A, NIPALS and the SVD of Cxy) and CCA (canonical,
;; mode B).  The cross products are formed here, centred, by loops; the
;; weights and loadings print with svd_flip's signs, so they are
;; determined, and each value prints plus one, so that what rounds to
;; zero prints alike.  Plain the eigenproblems and the SVD are the
;; subset's; under --blas dsyevd and dgesdd.
(include "../examples/kernel-only/pls.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (+ 1.0 (vector-ref v j))) (display " "))
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

(define (run x y mode canon algo)
  (let ((n 10) (p 3) (q 2) (k 2))
    (let ((cxx (make-vector (* p p) 0.0))
          (cxy (make-vector (* p q) 0.0))
          (cyy (make-vector (* q q) 0.0))
          (xw (make-vector (* p k) 0.0))
          (yw (make-vector (* q k) 0.0))
          (xl (make-vector (* p k) 0.0))
          (yl (make-vector (* q k) 0.0))
          (niter (make-vector k 0)))
      (cross x x cxx n p p)
      (cross x y cxy n p q)
      (cross y y cyy n q q)
      (display (pls-fit cxx cxy cyy xw yw xl yl niter p q k mode canon algo 500 1e-12)) (newline)
      (show xw (* p k))
      (show yw (* q k))
      (show xl (* p k))
      (show yl (* q k))
      0)))

(define (main)
  (let ((x0 (vector 0.31 -0.72 1.05  0.18 -0.44 0.93  0.67 -1.21 -0.09  0.52 1.38 -0.35
                   -0.81 -0.27 0.44  1.12 0.05 -0.63  -0.38 0.91 0.27  0.74 -0.16 1.41
                   -1.02 0.58 -0.47  0.29 1.17 0.83))
        (y0 (vector 0.4 -0.2  0.9 0.1  -0.3 0.7  0.2 -0.8  0.6 0.5
                   -0.7 0.3  0.1 0.9  -0.5 -0.4  0.8 -0.1  -0.2 0.6))
        (n 10) (p 3) (q 2))
    ;; runtime-sized copies: a literal's size is its C++ type, and cross
    ;; takes both blocks
    (let ((x (make-vector (* n p) 0.0))
          (y (make-vector (* n q) 0.0)))
      (do ((s 0 (+ s 1))) ((= s (* n p))) (vector-set! x s (vector-ref x0 s)))
      (do ((s 0 (+ s 1))) ((= s (* n q))) (vector-set! y s (vector-ref y0 s)))
      (run x y 0 0 0)
      (run x y 0 1 0)
      (run x y 0 1 1)
      (run x y 1 1 0)
      0)))

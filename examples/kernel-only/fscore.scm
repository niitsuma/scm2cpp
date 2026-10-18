;;;; The univariate F statistics of scikit-learn's feature selection,
;;;; whole: f_regression (through r_regression) for Q targets at once,
;;;; and f_classif (f_oneway), written out in the subset.
;;;;
;;;; f-regression: with CENTER 1 each target is centred, each feature's
;;;; norm is sqrt(sum x^2 - n mean^2) (scikit-learn's: X itself is not
;;;; centred), r = x'y / |x| / |y|, and F = r^2 / (1 - r^2) dof, dof =
;;;; n - 2 (n - 1 without centring).  The n x q targets are one matrix,
;;;; so X'Y is one product (--blas dgemm, --cublas on the device): one
;;;; target is scikit-learn's call, many are what a loop of them would
;;;; give.  R (p x q) gets the correlations, F (p x q) the statistics.
;;;;
;;;; f-classif: LAB holds each row's class index (K classes); the class
;;;; sums are the product of the one-hot matrix and X, then f_oneway's
;;;; sums of squares: sstot = sum x^2 - (sum x)^2 / n, ssbn = sum_k s_k^2 /
;;;; n_k - (sum x)^2 / n, F = (ssbn / (K - 1)) / ((sstot - ssbn) / (n -
;;;; K)).  F (p) gets the statistics.  p-values are the caller's (the F
;;;; distribution's tail).
;;;;

(define (f-regression x y r f center n p q)
  (let ((mx (make-vector p 0.0))
        (sx (make-vector p 0.0))
        (yc (make-vector (* n q) 0.0))
        (yn (make-vector q 0.0))
        (dof (exact->inexact (- n (if (= center 1) 2 1)))))
    ;; the features' sums and sums of squares, row by row
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((v (vector-ref x (+ (* i p) j))))
          (vector-set! mx j (+ (vector-ref mx j) v))
          (vector-set! sx j (+ (vector-ref sx j) (* v v))))))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! mx j (/ (vector-ref mx j) (exact->inexact n))))
    ;; the targets, centred, and their norms
    (do ((t 0 (+ t 1))) ((= t q))
      (let ((m 0.0) (s 0.0))
        (if (= center 1)
            (begin
              (do ((i 0 (+ i 1))) ((= i n)) (set! m (+ m (vector-ref y (+ (* i q) t)))))
              (set! m (/ m (exact->inexact n))))
            0)
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((v (- (vector-ref y (+ (* i q) t)) m)))
            (vector-set! yc (+ (* i q) t) v)
            (set! s (+ s (* v v)))))
        (vector-set! yn t (sqrt s))))
    (with-arrays ((x (n p)) (yc (n q)) (r (p q)))
      (array-set! r (matmul (transpose x) yc)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((xn (sqrt (if (= center 1)
                          (- (vector-ref sx j) (* (exact->inexact n) (* (vector-ref mx j) (vector-ref mx j))))
                          (vector-ref sx j)))))
        (do ((t 0 (+ t 1))) ((= t q))
          (let ((rr (/ (/ (vector-ref r (+ (* j q) t)) xn) (vector-ref yn t))))
            (vector-set! r (+ (* j q) t) rr)
            (vector-set! f (+ (* j q) t) (* (/ (* rr rr) (- 1.0 (* rr rr))) dof))))))
    0))

(define (f-classif x lab f n p k)
  (let ((oh (make-vector (* n k) 0.0))
        (cs (make-vector (* k p) 0.0))
        (cnt (make-vector k 0.0))
        (ss (make-vector p 0.0))
        (tot (make-vector p 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((c (vector-ref lab i)))
        (vector-set! oh (+ (* i k) c) 1.0)
        (vector-set! cnt c (+ (vector-ref cnt c) 1.0)))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((v (vector-ref x (+ (* i p) j))))
          (vector-set! ss j (+ (vector-ref ss j) (* v v))))))
    (with-arrays ((oh (n k)) (x (n p)) (cs (k p)))
      (array-set! cs (matmul (transpose oh) x)))
    (do ((c 0 (+ c 1))) ((= c k))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! tot j (+ (vector-ref tot j) (vector-ref cs (+ (* c p) j))))))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((sq (/ (* (vector-ref tot j) (vector-ref tot j)) (exact->inexact n)))
            (ssbn 0.0))
        (do ((c 0 (+ c 1))) ((= c k))
          (set! ssbn (+ ssbn (/ (* (vector-ref cs (+ (* c p) j)) (vector-ref cs (+ (* c p) j)))
                                (vector-ref cnt c)))))
        (set! ssbn (- ssbn sq))
        (let ((sswn (- (- (vector-ref ss j) sq) ssbn)))
          (vector-set! f j (/ (/ ssbn (exact->inexact (- k 1)))
                              (/ sswn (exact->inexact (- n k))))))))
    0))

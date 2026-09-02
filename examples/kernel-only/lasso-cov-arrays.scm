;; The covariance-update lasso of lasso-cov.scm, written against a small
;; array-and-fold layer instead of flat subscripts and set! accumulators.
;;
;; The layer is the built-in macro set of array-macros.scm -- range-for,
;; range-fold, range-sum, with-arrays and the whole-vector forms -- which
;; the translator's pre-pass and the test oracle both seed from that one
;; file, so what either of them sees is exactly the flat-vector program
;; of lasso-cov.scm, and the generated C++ is the same loop nest with the
;; same arithmetic in the same order.

(include "soft-threshold.scm")

;; S(a,b) for every pair.  s is (wmax+1) x (wmax+1); one pass per lag.
(define (build-S ps s q cs n nobs wmax)
  (with-arrays ((s ((+ wmax 1) (+ wmax 1))))
    (range-for (dd (+ (* 2 wmax) 1))
      (let ((d (- dd wmax)))
        (range-for (i n) (vector-set! q i 0.0))
        (if (< d 0)
            (range-for (i (+ n d))
              (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d)))))
            (range-for (i d n)
              (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d))))))
        (vector-set! cs 0 0.0)
        (range-for (i n)
          (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
        (range-for (a (+ wmax 1))
          (let ((b (+ a d)))
            (if (< b 0)
                0
                (if (> b wmax)
                    0
                    (let ((m (- wmax a)))
                      (array-set! s a b
                                  (- (vector-ref cs (+ m nobs))
                                     (vector-ref cs m))))))))))
    0))

;; P(k) = sum_row ps[wmax+row-k] * y[row]: a fold, not a set! loop.
(define (build-P ps y pv nobs wmax)
  (range-for (k (+ wmax 1))
    (vector-set! pv k
                 (range-sum (r nobs)
                            (* (vector-ref ps (- (+ wmax r) k))
                               (vector-ref y r)))))
  0)

(define (build-G s pv g c wmax p)
  (with-arrays ((s ((+ wmax 1) (+ wmax 1)))
                (g (p p)))
    (let ((s00 (array-ref s 0 0)))
      (range-for (j p)
        (let ((wj (+ j 1)))
          (range-for (k p)
            (let ((wk (+ k 1)))
              (array-set! g j k
                          (/ (- (+ s00 (array-ref s wj wk))
                                (+ (array-ref s 0 wk)
                                   (array-ref s wj 0)))
                             (* wj wk)))))
          (vector-set! c j (/ (- (vector-ref pv 0) (vector-ref pv wj)) wj)))))
    0))

;; The sweeps.  The moved flag was a set! in the flat kernel; here it is
;; the accumulator of the coordinate fold, and the early exit reads it.
(define (cov-descend g c beta lam iters nobs p)
  (with-arrays ((g (p p)) (c (p)))
    (let ((stop 0))
      (do ((sweep 0 (+ sweep 1)))
          ((or (= sweep iters) (= stop 1)))
        (let ((moved
               (range-fold ((m 0) (j p))
                 (let ((gjj (array-ref g j j))
                       (old (vector-ref beta j)))
                   (let ((bnew (/ (soft-threshold
                                   (+ (array-ref c j) (* old gjj))
                                   (* lam (* 1.0 nobs)))
                                  gjj)))
                     (vector-set! beta j bnew)
                     (let ((d (- bnew old)))
                       (if (= d 0.0)
                           m
                           (begin
                             (array-dec! c (scale d (row g j)))
                             1))))))))
          (if (= moved 0) (set! stop 1) 0))))
    0))

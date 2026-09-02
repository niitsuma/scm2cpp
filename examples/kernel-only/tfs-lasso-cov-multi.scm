;; Lasso over moving-average features of several series at once.
;;
;; With m series the design matrix has m*wmax columns, one for each pair of
;; a series c and a window w: X[row][(c,w)] = (ps_c[t]-ps_c[t-w])/w. The
;; covariance form carries over unchanged, because expanding a Gram entry
;;
;;   G[(c,w)][(c',w')] = (S(c,c',0,0) - S(c,c',0,w') - S(c,c',w,0)
;;                        + S(c,c',w,w')) / (w*w')
;;
;; leaves inner products of two prefix-sum arrays, now possibly of
;; different series. Fixing the lag makes each a sliding-window sum as
;; before, so one prefix-sum pass per (series pair, lag) gives every entry:
;; O(m^2 * wmax * n) rather than the O(n * (m*wmax)^2) of forming the
;; matrix, the same factor of wmax as in the single-series case.
;;
;; The prefix sums of all m series are held end to end in one array, series
;; c occupying [c*n, (c+1)*n), because the subset has no arrays of arrays.
;; S is indexed likewise: (c*m + c')*(wmax+1)^2 + a*(wmax+1) + b.

(include "soft-threshold.scm")

;; S(c,c2,a,b) = sum_row ps_c[wmax+row-a] * ps_c2[wmax+row-b], every entry.
(define (build-S-multi ps s q cs n nobs wmax m)
  (let ((w1 (+ wmax 1)))
    (with-arrays ((ps (m n))
                  (s (m m w1 w1)))
      (range-for (si m)
        (range-for (sj m)
          (range-for (dd (+ (* 2 wmax) 1))
            (let ((d (- dd wmax)))
              (range-for (i n) (vector-set! q i 0.0))
              (if (< d 0)
                  (range-for (i (+ n d))
                    (vector-set! q i (* (array-ref ps si i)
                                        (array-ref ps sj (- i d)))))
                  (range-for (i d n)
                    (vector-set! q i (* (array-ref ps si i)
                                        (array-ref ps sj (- i d))))))
              (vector-set! cs 0 0.0)
              (range-for (i n)
                (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
              (range-for (a w1)
                (let ((b (+ a d)))
                  (if (< b 0)
                      0
                      (if (> b wmax)
                          0
                          (let ((mm (- wmax a)))
                            (array-set! s si sj a b
                                        (- (vector-ref cs (+ mm nobs))
                                           (vector-ref cs mm))))))))))))
      0)))

;; P(c,k) = sum_row ps_c[wmax+row-k] * y[row].
(define (build-P-multi ps y pv n nobs wmax m)
  (with-arrays ((ps (m n))
                (pv (m (+ wmax 1))))
    (range-for (si m)
      (range-for (k (+ wmax 1))
        (array-set! pv si k
                    (range-sum (r nobs)
                               (* (array-ref ps si (- (+ wmax r) k))
                                  (vector-ref y r))))))
    0))

;; Column index of the pair (series c, window w).
(define (build-G-multi s pv g xty wmax m p)
  (let ((w1 (+ wmax 1)))
    (with-arrays ((s (m m w1 w1))
                  (pv (m w1))
                  (g (p p)))
      (range-for (i p)
        (let ((ci (quotient i wmax))
              (wi (+ (remainder i wmax) 1)))
          (range-for (j p)
            (let ((cj (quotient j wmax))
                  (wj (+ (remainder j wmax) 1)))
              (array-set! g i j
                          (/ (- (+ (array-ref s ci cj 0 0)
                                   (array-ref s ci cj wi wj))
                                (+ (array-ref s ci cj 0 wj)
                                   (array-ref s ci cj wi 0)))
                             (* wi wj)))))
          (vector-set! xty i (/ (- (array-ref pv ci 0)
                                   (array-ref pv ci wi))
                                wi))))
      0)))

;; The sweeps, unchanged: each coordinate is O(p) and touches no observation.
(define (cov-descend-multi g c beta lam iters nobs p)
  (with-arrays ((g (p p)) (c (p)))
    (range-for (sweep iters)
      (range-for (j p)
        (let ((gjj (array-ref g j j))
              (old (vector-ref beta j)))
          (let ((bnew (/ (soft-threshold (+ (array-ref c j) (* old gjj))
                                         (* lam (* 1.0 nobs)))
                         gjj)))
            (vector-set! beta j bnew)
            (let ((d (- bnew old)))
              (array-dec! c (scale d (row g j))))))))
    0))

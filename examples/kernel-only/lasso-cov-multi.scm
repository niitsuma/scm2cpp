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

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

;; S(c,c2,a,b) = sum_row ps_c[wmax+row-a] * ps_c2[wmax+row-b], every entry.
(define (build-S-multi ps s q cs n nobs wmax m)
  (let ((w1 (+ wmax 1)))
    (do ((si 0 (+ si 1)))
        ((= si m))
      (do ((sj 0 (+ sj 1)))
          ((= sj m))
        (do ((d (- 0 wmax) (+ d 1)))
            ((= d (+ wmax 1)))
          (do ((i 0 (+ i 1))) ((= i n))
            (vector-set! q i 0.0))
          (if (< d 0)
              (do ((i 0 (+ i 1))) ((= i (+ n d)))
                (vector-set! q i (* (vector-ref ps (+ (* si n) i))
                                    (vector-ref ps (+ (* sj n) (- i d))))))
              (do ((i d (+ i 1))) ((= i n))
                (vector-set! q i (* (vector-ref ps (+ (* si n) i))
                                    (vector-ref ps (+ (* sj n) (- i d)))))))
          (vector-set! cs 0 0.0)
          (do ((i 0 (+ i 1))) ((= i n))
            (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
          (do ((a 0 (+ a 1)))
              ((= a w1))
            (let ((b (+ a d)))
              (if (< b 0)
                  0
                  (if (> b wmax)
                      0
                      (let ((mm (- wmax a)))
                        (vector-set! s (+ (* (+ (* si m) sj) (* w1 w1))
                                          (+ (* a w1) b))
                                     (- (vector-ref cs (+ mm nobs))
                                        (vector-ref cs mm))))))))))))
  0)

;; P(c,k) = sum_row ps_c[wmax+row-k] * y[row].
(define (build-P-multi ps y pv n nobs wmax m)
  (do ((si 0 (+ si 1)))
      ((= si m))
    (do ((k 0 (+ k 1)))
        ((= k (+ wmax 1)))
      (let ((acc 0.0))
        (do ((r 0 (+ r 1))) ((= r nobs))
          (set! acc (+ acc (* (vector-ref ps (+ (* si n) (- (+ wmax r) k)))
                              (vector-ref y r)))))
        (vector-set! pv (+ (* si (+ wmax 1)) k) acc))))
  0)

;; Column index of the pair (series c, window w).
(define (build-G-multi s pv g xty wmax m p)
  (let ((w1 (+ wmax 1)))
    (do ((i 0 (+ i 1)))
        ((= i p))
      (let ((ci (quotient i wmax))
            (wi (+ (remainder i wmax) 1)))
        (do ((j 0 (+ j 1)))
            ((= j p))
          (let ((cj (quotient j wmax))
                (wj (+ (remainder j wmax) 1)))
            (let ((base (* (+ (* ci m) cj) (* w1 w1))))
              (vector-set! g (+ (* i p) j)
                           (/ (- (+ (vector-ref s base)
                                    (vector-ref s (+ base (+ (* wi w1) wj))))
                                 (+ (vector-ref s (+ base wj))
                                    (vector-ref s (+ base (* wi w1)))))
                              (* wi wj))))))
        (vector-set! xty i (/ (- (vector-ref pv (* ci w1))
                               (vector-ref pv (+ (* ci w1) wi)))
                            wi)))))
  0)

;; The sweeps, unchanged: each coordinate is O(p) and touches no observation.
(define (cov-descend-multi g c beta lam iters nobs p)
  (do ((sweep 0 (+ sweep 1)))
      ((= sweep iters))
    (do ((j 0 (+ j 1)))
        ((= j p))
      (let ((gjj (vector-ref g (+ (* j p) j)))
            (old (vector-ref beta j)))
        (let ((bnew (/ (soft-threshold (+ (vector-ref c j) (* old gjj))
                                       (* lam (* 1.0 nobs)))
                       gjj)))
          (vector-set! beta j bnew)
          (let ((d (- bnew old)))
            (do ((k 0 (+ k 1)))
                ((= k p))
              (vector-set! c k (- (vector-ref c k)
                                  (* d (vector-ref g (+ (* j p) k)))))))))))
  0)

;;;; RANSAC for a linear model, whole: scikit-learn's
;;;; RANSACRegressor.fit around LinearRegression, written out in the
;;;; subset.
;;;;
;;;; Each trial fits ordinary least squares with an intercept to the
;;;; MINSAMPLES points of its subset (the next row of SUBSETS), counts the
;;;; points whose absolute residual is at most THRESH, and keeps the fit
;;;; when it has more such inliers than the best so far, or as many with
;;;; an R^2 on its inliers at least as high.  Every kept fit lowers the
;;;; number of trials to scikit-learn's _dynamic_max_trials: enough
;;;; subsets that one is outlier-free with probability STOPPROB.  The
;;;; model is then refitted on the best fit's inliers.  The subsets are
;;;; the caller's -- scikit-learn draws them one per trial with
;;;; sample_without_replacement from its random_state, and the package
;;;; draws the same ones the same way, MAXTRIALS of them, in order.
;;;;
;;;; Least squares is LinearRegression's: the data are centred on their
;;;; means, the slope solves the normal equations of the centred data (a
;;;; Cholesky solve; scikit-learn's lstsq gives the same solution to
;;;; rounding for a full-rank subset), the intercept is the mean of y
;;;; less the means of X along the slope.
;;;;
;;;; X is n rows of p.  COEF gets the slope (p) and OUT[0] the intercept;
;;;; MASK gets 1.0 for the inliers of the best fit.  Returns the number of
;;;; trials (scikit-learn's n_trials_).
;;;;
;;;;[ja] 線形モデルの RANSAC 全体: scikit-learn の RANSACRegressor.fit を
;;;;[ja] LinearRegression とともにそのままサブセットで書いたもの。試行ごとに
;;;;[ja] 部分集合(SUBSETS の次の行)で切片つき最小二乗、残差が THRESH 以下の点を
;;;;[ja] 数え、多ければ(同数なら R^2 が下がらなければ)採用。採用のたびに試行回数の
;;;;[ja] 上限を _dynamic_max_trials に下げる。最後に最良の当てはめのインライアで
;;;;[ja] 当てはめ直す。部分集合は呼び出し側が scikit-learn と同じ乱数の呼び方で作る。

;; least squares with an intercept over the M rows ROWS of X: the slope
;; into W, the intercept returned.  G (p x p), C, L, Z, XM are scratch.
(define (ols-rows x y rows m w g c l z xm n p)
  (let ((ym 0.0))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! xm j 0.0))
    (do ((r 0 (+ r 1))) ((= r m))
      (let ((i (vector-ref rows r)))
        (set! ym (+ ym (vector-ref y i)))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! xm j (+ (vector-ref xm j) (vector-ref x (+ (* i p) j)))))))
    (set! ym (/ ym (* 1.0 m)))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! xm j (/ (vector-ref xm j) (* 1.0 m))))
    ;; the normal equations of the centred rows
    (do ((t 0 (+ t 1))) ((= t (* p p))) (vector-set! g t 0.0))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! c j 0.0))
    (do ((r 0 (+ r 1))) ((= r m))
      (let ((i (vector-ref rows r)))
        (let ((yc (- (vector-ref y i) ym)))
          (do ((a 0 (+ a 1))) ((= a p))
            (let ((xa (- (vector-ref x (+ (* i p) a)) (vector-ref xm a))))
              (vector-set! c a (+ (vector-ref c a) (* xa yc)))
              (do ((b 0 (+ b 1))) ((> b a))
                (let ((xb (- (vector-ref x (+ (* i p) b)) (vector-ref xm b))))
                  (vector-set! g (+ (* a p) b) (+ (vector-ref g (+ (* a p) b)) (* xa xb))))))))))
    ;; Cholesky of the lower triangle, then the two triangular solves
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((s (vector-ref g (+ (* j p) j))))
        (do ((k 0 (+ k 1))) ((= k j))
          (set! s (- s (* (vector-ref l (+ (* j p) k)) (vector-ref l (+ (* j p) k))))))
        (vector-set! l (+ (* j p) j) (sqrt (if (> s 0.0) s 1e-300)))
        (do ((i (+ j 1) (+ i 1))) ((>= i p))
          (let ((t (vector-ref g (+ (* i p) j))))
            (do ((k 0 (+ k 1))) ((= k j))
              (set! t (- t (* (vector-ref l (+ (* i p) k)) (vector-ref l (+ (* j p) k))))))
            (vector-set! l (+ (* i p) j) (/ t (vector-ref l (+ (* j p) j))))))))
    (do ((i 0 (+ i 1))) ((= i p))
      (let ((t (vector-ref c i)))
        (do ((k 0 (+ k 1))) ((= k i))
          (set! t (- t (* (vector-ref l (+ (* i p) k)) (vector-ref z k)))))
        (vector-set! z i (/ t (vector-ref l (+ (* i p) i))))))
    (do ((ii 0 (+ ii 1))) ((= ii p))
      (let ((i (- (- p 1) ii)))
        (let ((t (vector-ref z i)))
          (do ((k (+ i 1) (+ k 1))) ((>= k p))
            (set! t (- t (* (vector-ref l (+ (* k p) i)) (vector-ref w k)))))
          (vector-set! w i (/ t (vector-ref l (+ (* i p) i)))))))
    (let ((b ym))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! b (- b (* (vector-ref xm j) (vector-ref w j)))))
      b)))

(define (ransac x y subsets coef mask out maxtrials minsamples thresh stopprob n p)
  (let ((rows (make-vector n 0))
        (inl (make-vector n 0))
        (w (make-vector p 0.0))
        (g (make-vector (* p p) 0.0))
        (c (make-vector p 0.0))
        (l (make-vector (* p p) 0.0))
        (z (make-vector p 0.0))
        (xm (make-vector p 0.0))
        (nbest 1) (scorebest -1e300) (found 0)
        (trials 0) (limit (* 1.0 maxtrials))
        (eps 2.220446049250313e-16))
    (do () ((>= (* 1.0 trials) limit))
      (let ((t trials))
        (set! trials (+ trials 1))
        (do ((r 0 (+ r 1))) ((= r minsamples))
          (vector-set! rows r (vector-ref subsets (+ (* t minsamples) r))))
        (let ((b (ols-rows x y rows minsamples w g c l z xm n p))
              (ninl 0))
          ;; the inliers of this fit, and their count
          (do ((i 0 (+ i 1))) ((= i n))
            (let ((pred b))
              (do ((j 0 (+ j 1))) ((= j p))
                (set! pred (+ pred (* (vector-ref x (+ (* i p) j)) (vector-ref w j)))))
              (let ((res (- (vector-ref y i) pred)))
                (if (<= (if (< res 0.0) (- 0.0 res) res) thresh)
                    (begin (vector-set! inl ninl i) (set! ninl (+ ninl 1)))
                    0))))
          (if (>= ninl nbest)
              ;; the fit's R^2 on its inliers (LinearRegression.score)
              (let ((ym 0.0) (sstot 0.0) (ssres 0.0))
                (do ((r 0 (+ r 1))) ((= r ninl))
                  (set! ym (+ ym (vector-ref y (vector-ref inl r)))))
                (set! ym (/ ym (* 1.0 ninl)))
                (do ((r 0 (+ r 1))) ((= r ninl))
                  (let ((i (vector-ref inl r)))
                    (let ((pred b))
                      (do ((j 0 (+ j 1))) ((= j p))
                        (set! pred (+ pred (* (vector-ref x (+ (* i p) j)) (vector-ref w j)))))
                      (let ((dr (- (vector-ref y i) pred)) (dt (- (vector-ref y i) ym)))
                        (set! ssres (+ ssres (* dr dr)))
                        (set! sstot (+ sstot (* dt dt)))))))
                (let ((score (if (> sstot 0.0) (- 1.0 (/ ssres sstot)) (if (> ssres 0.0) 0.0 1.0))))
                  (if (not (and (= ninl nbest) (< score scorebest)))
                      (begin
                        (set! found 1)
                        (set! nbest ninl)
                        (set! scorebest score)
                        (do ((i 0 (+ i 1))) ((= i n)) (vector-set! mask i 0.0))
                        (do ((r 0 (+ r 1))) ((= r ninl)) (vector-set! mask (vector-ref inl r) 1.0))
                        ;; scikit-learn's _dynamic_max_trials
                        (let ((ratio (/ (* 1.0 nbest) (* 1.0 n)))
                              (nom (if (> (- 1.0 stopprob) eps) (- 1.0 stopprob) eps)))
                          (let ((pw (let ((acc 1.0))
                                      (do ((s 0 (+ s 1))) ((= s minsamples))
                                        (set! acc (* acc ratio)))
                                      acc)))
                            (let ((denom (if (> (- 1.0 pw) eps) (- 1.0 pw) eps)))
                              (let ((dyn (if (= nom 1.0) 0.0
                                             (if (= denom 1.0) 1e300
                                                 (let ((q (/ (log nom) (log denom))))
                                                   ;; ceil q, as -floor(-q)
                                                   (let ((cq (- 0.0 (floor (- 0.0 q)))))
                                                     (if (< cq 0.0) (- 0.0 cq) cq)))))))
                                (if (< dyn limit) (set! limit dyn) 0))))))
                      0)))
              0))))
    ;; the model refitted on the best fit's inliers
    (let ((m 0))
      (do ((i 0 (+ i 1))) ((= i n))
        (if (= (vector-ref mask i) 1.0) (begin (vector-set! rows m i) (set! m (+ m 1))) 0))
      (vector-set! out 0 (ols-rows x y rows m coef g c l z xm n p)))
    trials))

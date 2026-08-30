;; Lasso over moving-average features by covariance updates.
;;
;; The design matrix is not arbitrary: column j is the moving average of
;; the base sequence at window j+1, so X[row][j] = (ps[t]-ps[t-w])/w with
;; t = wmax+row. Two consequences are used here.
;;
;; First, the Gram matrix G = X^T X and the vector c = X^T y are built from
;; the prefix sums rather than from X. Writing S(a,b) for the inner product
;; of ps shifted by a and by b over the observation window,
;;
;;   G[j][k] = (S(0,0) - S(0,wk) - S(wj,0) + S(wj,wk)) / (wj*wk)
;;
;; and fixing the lag d = b-a makes S(a,a+d) a sliding-window sum, so one
;; prefix-sum pass per lag gives every entry. That is O(n*p) work, not the
;; O(n*p^2) a general Gram matrix costs, and X is never formed.
;;
;; Second, the solver keeps c = X^T r rather than the residual r itself.
;; Changing beta[j] by d changes r by -d*X[j], hence c by -d*G[:,j]: each
;; coordinate step is O(p) and does not touch the n observations at all.
;;
;; Everything after the preparation is therefore independent of n.

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

;; S(a,b) for every pair, as a flat (wmax+1)^2 array. One pass per lag.
(define (build-S ps s q cs n nobs wmax)
  (do ((d (- 0 wmax) (+ d 1)))
      ((= d (+ wmax 1)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! q i 0.0))
    (if (< d 0)
        (do ((i 0 (+ i 1))) ((= i (+ n d)))
          (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d)))))
        (do ((i d (+ i 1))) ((= i n))
          (vector-set! q i (* (vector-ref ps i) (vector-ref ps (- i d))))))
    (vector-set! cs 0 0.0)
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! cs (+ i 1) (+ (vector-ref cs i) (vector-ref q i))))
    (do ((a 0 (+ a 1)))
        ((= a (+ wmax 1)))
      (let ((b (+ a d)))
        (if (< b 0)
            0
            (if (> b wmax)
                0
                (let ((m (- wmax a)))
                  (vector-set! s (+ (* a (+ wmax 1)) b)
                               (- (vector-ref cs (+ m nobs))
                                  (vector-ref cs m)))))))))
  0)

;; P(k) = sum_row ps[wmax+row-k] * y[row], for c = X^T y.
(define (build-P ps y pv nobs wmax)
  (do ((k 0 (+ k 1)))
      ((= k (+ wmax 1)))
    (let ((acc 0.0))
      (do ((r 0 (+ r 1))) ((= r nobs))
        (set! acc (+ acc (* (vector-ref ps (- (+ wmax r) k))
                            (vector-ref y r)))))
      (vector-set! pv k acc)))
  0)

(define (build-G s pv g c wmax p)
  (let ((s00 (vector-ref s 0)))
    (do ((j 0 (+ j 1)))
        ((= j p))
      (let ((wj (+ j 1)))
        (do ((k 0 (+ k 1)))
            ((= k p))
          (let ((wk (+ k 1)))
            (vector-set! g (+ (* j p) k)
                         (/ (- (+ s00 (vector-ref s (+ (* wj (+ wmax 1)) wk)))
                               (+ (vector-ref s wk)
                                  (vector-ref s (* wj (+ wmax 1)))))
                            (* wj wk)))))
        (vector-set! c j (/ (- (vector-ref pv 0) (vector-ref pv wj)) wj)))))
  0)

;; The sweeps: each coordinate reads one entry of c and updates all of it.
;;
;; A sweep in which no coefficient moved has reached a fixed point: c was not
;; touched either, so every later sweep would repeat it exactly. Leaving then
;; costs nothing in accuracy -- the answer is the one iters sweeps would have
;; produced, bit for bit -- and nothing in speed either, because whether a
;; coefficient moved is already tested to decide whether the inner loop can
;; be skipped. Where the iteration settles, which is the sparse end of the
;; path, this is most of the sweeps.
;;
;; A tolerance on the coefficient movement was tried here and taken out
;; again: the comparisons it needs sit in the coordinate loop and cost more
;; than they save, and on a design matrix of overlapping moving averages the
;; movement per sweep stays above any useful tolerance for far longer than
;; one would want to run. Ask for more sweeps instead, and know that the
;; answer at 500 is not the converged one.
(define (cov-descend g c beta lam iters nobs p)
  (let ((stop 0))
   (do ((sweep 0 (+ sweep 1)))
       ((or (= sweep iters) (= stop 1)))
    (let ((moved 0))
     (do ((j 0 (+ j 1)))
         ((= j p))
       (let ((gjj (vector-ref g (+ (* j p) j)))
             (old (vector-ref beta j)))
         (let ((bnew (/ (soft-threshold (+ (vector-ref c j) (* old gjj))
                                        (* lam (* 1.0 nobs)))
                        gjj)))
           (vector-set! beta j bnew)
           (let ((d (- bnew old)))
             ;; Most coefficients are zero and stay zero -- that is what the
             ;; penalty is for -- and the update below then subtracts zero
             ;; from every entry of c. Skipping it is exact, and it removes
             ;; most of the work: the sweeps cost O(p) per coordinate that
             ;; moves rather than O(p) per coordinate.
             (if (= d 0.0)
                 0
                 (begin
                   (set! moved 1)
                   (do ((k 0 (+ k 1)))
                       ((= k p))
                     (vector-set! c k (- (vector-ref c k)
                                         (* d (vector-ref g (+ (* j p) k))))))))))))
     (if (= moved 0) (set! stop 1) 0))))
  0)

;; The elastic net over the same machinery.  The L2 half of the penalty
;; never touches the residual correlations -- it is not part of X'r --
;; so C is maintained exactly as the lasso maintains it, and the only
;; changes are in the coordinate update itself: the threshold carries
;; the L1 share of the penalty, and the denominator gains the L2 share.
;; LAM1 and LAM2 are alpha * l1_ratio and alpha * (1 - l1_ratio) in
;; scikit-learn's parametrization (fit_intercept=false); both are scaled
;; by NOBS here, as the lasso's LAM is.  With LAM2 = 0 every operation
;; is bit-identical to cov-descend: x + 0.0 is x, and the threshold is
;; unchanged, so the lasso is the special case rather than a separate
;; path.
(define (enet-descend g c beta lam1 lam2 iters nobs p)
  (let ((stop 0))
   (do ((sweep 0 (+ sweep 1)))
       ((or (= sweep iters) (= stop 1)))
    (let ((moved 0))
     (do ((j 0 (+ j 1)))
         ((= j p))
       (let ((gjj (vector-ref g (+ (* j p) j)))
             (old (vector-ref beta j)))
         (let ((bnew (/ (soft-threshold (+ (vector-ref c j) (* old gjj))
                                        (* lam1 (* 1.0 nobs)))
                        (+ gjj (* lam2 (* 1.0 nobs))))))
           (vector-set! beta j bnew)
           (let ((d (- bnew old)))
             (if (= d 0.0)
                 0
                 (begin
                   (set! moved 1)
                   (do ((k 0 (+ k 1)))
                       ((= k p))
                     (vector-set! c k (- (vector-ref c k)
                                         (* d (vector-ref g (+ (* j p) k))))))))))))
     (if (= moved 0) (set! stop 1) 0))))
  0)

;; The multi-task lasso over the same machinery.  W is p x ntask flat,
;; and the penalty ties each feature's row together: the row enters or
;; leaves for all tasks at once, under the L2 norm of the row.  C is
;; X'Y - G W maintained per task exactly as the single-task C is (the
;; L2 half of an elastic net never appears in it), so the update is the
;; block form of enet-descend: the row's unpenalized optimum z has
;; z[t] = C[j][t] + G[j][j] * W[j][t], and the row moves to
;; z * max(0, ||z|| - lam1*n) / (||z|| * (G[j][j] + lam2*n)),
;; which is scikit-learn's MultiTaskElasticNet objective with
;; fit_intercept=false, and its MultiTaskLasso at lam2 = 0.  A row at
;; zero whose z stays under the threshold moves nothing and costs no
;; update of C, which is the same sparse-sweep economy the single-task
;; kernels live on.
(define (mt-descend g c w lam1 lam2 iters nobs p ntask)
  (let ((stop 0))
   (do ((sweep 0 (+ sweep 1)))
       ((or (= sweep iters) (= stop 1)))
    (let ((moved 0))
     (do ((j 0 (+ j 1)))
         ((= j p))
       (let ((gjj (vector-ref g (+ (* j p) j)))
             (nrm2 0.0))
         (do ((t 0 (+ t 1))) ((= t ntask))
           (let ((z (+ (vector-ref c (+ (* j ntask) t))
                       (* gjj (vector-ref w (+ (* j ntask) t))))))
             (set! nrm2 (+ nrm2 (* z z)))))
         (let ((nrm (sqrt nrm2))
               (thr (* lam1 (* 1.0 nobs))))
           (let ((scale (if (> nrm thr)
                            (/ (- nrm thr)
                               (* nrm (+ gjj (* lam2 (* 1.0 nobs)))))
                            0.0)))
             (do ((t 0 (+ t 1))) ((= t ntask))
               (let ((old (vector-ref w (+ (* j ntask) t))))
                 (let ((wnew (* scale
                                (+ (vector-ref c (+ (* j ntask) t))
                                   (* gjj old)))))
                   (vector-set! w (+ (* j ntask) t) wnew)
                   (let ((d (- wnew old)))
                     (if (= d 0.0)
                         0
                         (begin
                           (set! moved 1)
                           (do ((k 0 (+ k 1)))
                               ((= k p))
                             (vector-set! c (+ (* k ntask) t)
                                          (- (vector-ref c (+ (* k ntask) t))
                                             (* d (vector-ref g (+ (* j p) k))))))))))))))))
     (if (= moved 0) (set! stop 1) 0))))
  0)

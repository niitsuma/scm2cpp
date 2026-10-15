;;;; Limited-memory BFGS without bounds, as scipy's L-BFGS-B runs it for
;;;; scikit-learn (LogisticRegression(solver="lbfgs"), HuberRegressor):
;;;; written out in the subset.
;;;;
;;;; Without bounds L-BFGS-B's direction (the Cauchy point, then the
;;;; subspace minimisation of the compact model) is the minimiser of the
;;;; quadratic model, -H g, H the inverse of the memory's BFGS matrix over
;;;; theta I; the two-loop recursion computes the same direction.  M pairs
;;;; are kept (scipy's maxcor, 10).  The first step, and the first after a
;;;; restart, is -g; the first iteration tries the step 1/|d|, every later
;;;; one the step 1.  The line search is MINPACK-2's dcsrch with dcstep
;;;; (More and Thuente), with L-BFGS-B's constants: ftol 1e-3, gtol 0.9,
;;;; xtol 0.1, the step at most 1e10, MAXLS evaluations at most.  A pair
;;;; enters the memory when s'y > eps (-g'd) stp, s'y taken as L-BFGS-B
;;;; takes it, (g_new.d - g_old.d) stp.  A failed search, or a direction
;;;; that does not descend, empties the memory and retries along -g; a
;;;; second failure along -g ends the fit.  The fit stops when the largest
;;;; gradient entry is at most PGTOL (scipy's gtol, scikit-learn's tol),
;;;; when f fell by at most FTOL max(|f_old|, |f|, 1) (scikit-learn passes
;;;; 64 eps), or after MAXITER iterations.
;;;;
;;;; The objective is lbfgs-fg, which a program including this file
;;;; defines: (lbfgs-fg kind w g x y aux work n p k) returns f at W and
;;;; writes the gradient into G; KIND selects the objective, X Y AUX WORK
;;;; N P K are handed through.  W (NV entries) is the start and the
;;;; result; OUT[0] gets f, OUT[1] the number of function evaluations.
;;;; Returns the number of iterations (scipy's nit).
;;;;
;;;;[ja] 制約なしの L-BFGS: scipy の L-BFGS-B が scikit-learn
;;;;[ja] (LogisticRegression の lbfgs、HuberRegressor)に対して行う計算を
;;;;[ja] サブセットで書いたもの。制約がなければ L-BFGS-B の方向はモデルの
;;;;[ja] 最小点 -H g で、two-loop 再帰で同じ方向を求める。直線探索は MINPACK-2 の
;;;;[ja] dcsrch / dcstep(More-Thuente)を L-BFGS-B の定数で。停止は勾配の最大成分
;;;;[ja] が PGTOL 以下、f の相対減少が FTOL 以下、または MAXITER 反復。
;;;;[ja] 目的関数 lbfgs-fg はこのファイルを include する側が定義する。

(define (lb-abs a) (if (< a 0.0) (- 0.0 a) a))
(define (lb-max a b) (if (> a b) a b))
(define (lb-min a b) (if (< a b) a b))

;; MINPACK-2's dcstep: the safeguarded trial step and the new interval.
;; CS holds stx fx dx sty fy dy stp brackt; FP DP are f and f' at stp.
(define (lb-dcstep cs fp dp stpmin stpmax)
  (let ((stx (vector-ref cs 0)) (fx (vector-ref cs 1)) (dx (vector-ref cs 2))
        (sty (vector-ref cs 3)) (fy (vector-ref cs 4)) (dy (vector-ref cs 5))
        (stp (vector-ref cs 6)) (brackt (vector-ref cs 7))
        (stpf 0.0))
    (let ((sgnd (* dp (/ dx (lb-abs dx)))))
      (if (> fp fx)
          ;; a higher function value: the minimum is bracketed
          (begin
            (let ((th1 (+ (+ (/ (* 3.0 (- fx fp)) (- stp stx)) dx) dp)))
              (let ((s1 (lb-max (lb-abs th1) (lb-max (lb-abs dx) (lb-abs dp)))))
                (let ((ga1 (* s1 (sqrt (- (* (/ th1 s1) (/ th1 s1)) (* (/ dx s1) (/ dp s1)))))))
                  (let ((gm1 (if (< stp stx) (- 0.0 ga1) ga1)))
                    (let ((r1 (/ (+ (- gm1 dx) th1) (+ (+ (- gm1 dx) gm1) dp))))
                      (let ((stpc1 (+ stx (* r1 (- stp stx))))
                            (stpq1 (+ stx (* (/ (/ dx (+ (/ (- fx fp) (- stp stx)) dx)) 2.0) (- stp stx)))))
                        (if (< (lb-abs (- stpc1 stx)) (lb-abs (- stpq1 stx)))
                            (set! stpf stpc1)
                            (set! stpf (+ stpc1 (/ (- stpq1 stpc1) 2.0))))
                        (set! brackt 1.0)))))))
            0)
          (if (< sgnd 0.0)
              ;; derivatives of opposite sign: bracketed
              (begin
                (let ((th2 (+ (+ (/ (* 3.0 (- fx fp)) (- stp stx)) dx) dp)))
                  (let ((s2 (lb-max (lb-abs th2) (lb-max (lb-abs dx) (lb-abs dp)))))
                    (let ((ga2 (* s2 (sqrt (- (* (/ th2 s2) (/ th2 s2)) (* (/ dx s2) (/ dp s2)))))))
                      (let ((gm2 (if (> stp stx) (- 0.0 ga2) ga2)))
                        (let ((r2 (/ (+ (- gm2 dp) th2) (+ (+ (- gm2 dp) gm2) dx))))
                          (let ((stpc2 (+ stp (* r2 (- stx stp))))
                                (stpq2 (+ stp (* (/ dp (- dp dx)) (- stx stp)))))
                            (if (> (lb-abs (- stpc2 stp)) (lb-abs (- stpq2 stp)))
                                (set! stpf stpc2)
                                (set! stpf stpq2))
                            (set! brackt 1.0)))))))
                0)
              (if (< (lb-abs dp) (lb-abs dx))
                  ;; same sign, the derivative decreasing in magnitude
                  (begin
                    (let ((th3 (+ (+ (/ (* 3.0 (- fx fp)) (- stp stx)) dx) dp)))
                      (let ((s3 (lb-max (lb-abs th3) (lb-max (lb-abs dx) (lb-abs dp)))))
                        (let ((ga3 (* s3 (sqrt (lb-max 0.0 (- (* (/ th3 s3) (/ th3 s3)) (* (/ dx s3) (/ dp s3))))))))
                          (let ((gm3 (if (> stp stx) (- 0.0 ga3) ga3)))
                            (let ((r3 (/ (+ (- gm3 dp) th3) (+ (+ gm3 (- dx dp)) gm3))))
                              (let ((stpc3 (if (and (< r3 0.0) (not (= gm3 0.0)))
                                               (+ stp (* r3 (- stx stp)))
                                               (if (> stp stx) stpmax stpmin)))
                                    (stpq3 (+ stp (* (/ dp (- dp dx)) (- stx stp)))))
                                (if (= brackt 1.0)
                                    (begin
                                      (if (< (lb-abs (- stpc3 stp)) (lb-abs (- stpq3 stp)))
                                          (set! stpf stpc3)
                                          (set! stpf stpq3))
                                      (if (> stp stx)
                                          (set! stpf (lb-min (+ stp (* 0.66 (- sty stp))) stpf))
                                          (set! stpf (lb-max (+ stp (* 0.66 (- sty stp))) stpf))))
                                    (begin
                                      (if (> (lb-abs (- stpc3 stp)) (lb-abs (- stpq3 stp)))
                                          (set! stpf stpc3)
                                          (set! stpf stpq3))
                                      (set! stpf (lb-min stpmax stpf))
                                      (set! stpf (lb-max stpmin stpf))))))))))
                    0)
                  ;; same sign, the derivative not decreasing in magnitude
                  (if (= brackt 1.0)
                      (begin
                        (let ((th4 (+ (+ (/ (* 3.0 (- fp fy)) (- sty stp)) dy) dp)))
                          (let ((s4 (lb-max (lb-abs th4) (lb-max (lb-abs dy) (lb-abs dp)))))
                            (let ((ga4 (* s4 (sqrt (- (* (/ th4 s4) (/ th4 s4)) (* (/ dy s4) (/ dp s4)))))))
                              (let ((gm4 (if (> stp sty) (- 0.0 ga4) ga4)))
                                (let ((r4 (/ (+ (- gm4 dp) th4) (+ (+ (- gm4 dp) gm4) dy))))
                                  (set! stpf (+ stp (* r4 (- sty stp)))))))))
                        0)
                      (if (> stp stx) (set! stpf stpmax) (set! stpf stpmin))))))
      ;; the interval that contains a minimiser
      (if (> fp fx)
          (begin (vector-set! cs 3 stp) (vector-set! cs 4 fp) (vector-set! cs 5 dp))
          (begin
            (if (< sgnd 0.0)
                (begin (vector-set! cs 3 stx) (vector-set! cs 4 fx) (vector-set! cs 5 dx))
                0)
            (vector-set! cs 0 stp) (vector-set! cs 1 fp) (vector-set! cs 2 dp)))
      (vector-set! cs 6 stpf)
      (vector-set! cs 7 brackt)
      0)))

;; MINPACK-2's dcsrch.  LS holds stx fx gx sty fy gy brackt stage finit
;; ginit gtest width width1 stmin stmax stp.  lb-search-start takes f
;; and f' at step 0 and the first trial STP; lb-search-step takes f and
;; f' at the trial LS[15] and returns 0 (evaluate at the new LS[15]),
;; 1 (converged) or 2 (a warning: stop at LS[15] all the same).
(define (lb-search-start ls f g stp stpmin stpmax ftol)
  (vector-set! ls 0 0.0) (vector-set! ls 1 f) (vector-set! ls 2 g)
  (vector-set! ls 3 0.0) (vector-set! ls 4 f) (vector-set! ls 5 g)
  (vector-set! ls 6 0.0) (vector-set! ls 7 1.0)
  (vector-set! ls 8 f) (vector-set! ls 9 g) (vector-set! ls 10 (* ftol g))
  (vector-set! ls 11 (- stpmax stpmin)) (vector-set! ls 12 (/ (- stpmax stpmin) 0.5))
  (vector-set! ls 13 0.0) (vector-set! ls 14 (+ stp (* 4.0 stp)))
  (vector-set! ls 15 stp)
  0)

(define (lb-search-step ls cs f g ftol gtol xtol stpmin stpmax)
  (let ((stp (vector-ref ls 15))
        (finit (vector-ref ls 8)) (ginit (vector-ref ls 9)) (gtest (vector-ref ls 10))
        (task 0))
    (let ((ftest (+ finit (* stp gtest))))
      (if (and (= (vector-ref ls 7) 1.0) (and (<= f ftest) (>= g 0.0)))
          (vector-set! ls 7 2.0)
          0)
      ;; the warnings, then convergence
      (if (and (= (vector-ref ls 6) 1.0)
               (or (<= stp (vector-ref ls 13)) (>= stp (vector-ref ls 14))))
          (set! task 2) 0)
      (if (and (= (vector-ref ls 6) 1.0)
               (<= (- (vector-ref ls 14) (vector-ref ls 13)) (* xtol (vector-ref ls 14))))
          (set! task 2) 0)
      (if (and (= stp stpmax) (and (<= f ftest) (<= g gtest))) (set! task 2) 0)
      (if (and (= stp stpmin) (or (> f ftest) (>= g gtest))) (set! task 2) 0)
      (if (and (<= f ftest) (<= (lb-abs g) (* gtol (- 0.0 ginit)))) (set! task 1) 0)
      (if (= task 0)
          (begin
            (vector-set! cs 0 (vector-ref ls 0)) (vector-set! cs 3 (vector-ref ls 3))
            (vector-set! cs 6 stp) (vector-set! cs 7 (vector-ref ls 6))
            (if (and (= (vector-ref ls 7) 1.0) (and (<= f (vector-ref ls 1)) (> f ftest)))
                ;; the modified function, while in stage 1
                (begin
                  (vector-set! cs 1 (- (vector-ref ls 1) (* (vector-ref ls 0) gtest)))
                  (vector-set! cs 2 (- (vector-ref ls 2) gtest))
                  (vector-set! cs 4 (- (vector-ref ls 4) (* (vector-ref ls 3) gtest)))
                  (vector-set! cs 5 (- (vector-ref ls 5) gtest))
                  (lb-dcstep cs (- f (* stp gtest)) (- g gtest) (vector-ref ls 13) (vector-ref ls 14))
                  (vector-set! ls 1 (+ (vector-ref cs 1) (* (vector-ref cs 0) gtest)))
                  (vector-set! ls 2 (+ (vector-ref cs 2) gtest))
                  (vector-set! ls 4 (+ (vector-ref cs 4) (* (vector-ref cs 3) gtest)))
                  (vector-set! ls 5 (+ (vector-ref cs 5) gtest)))
                (begin
                  (vector-set! cs 1 (vector-ref ls 1)) (vector-set! cs 2 (vector-ref ls 2))
                  (vector-set! cs 4 (vector-ref ls 4)) (vector-set! cs 5 (vector-ref ls 5))
                  (lb-dcstep cs f g (vector-ref ls 13) (vector-ref ls 14))
                  (vector-set! ls 1 (vector-ref cs 1)) (vector-set! ls 2 (vector-ref cs 2))
                  (vector-set! ls 4 (vector-ref cs 4)) (vector-set! ls 5 (vector-ref cs 5))))
            (vector-set! ls 0 (vector-ref cs 0)) (vector-set! ls 3 (vector-ref cs 3))
            (vector-set! ls 6 (vector-ref cs 7))
            (let ((nstp (vector-ref cs 6))
                  (stx (vector-ref cs 0)) (sty (vector-ref cs 3)))
              ;; bisection when the interval does not shrink enough
              (if (= (vector-ref ls 6) 1.0)
                  (begin
                    (if (>= (lb-abs (- sty stx)) (* 0.66 (vector-ref ls 12)))
                        (set! nstp (+ stx (* 0.5 (- sty stx))))
                        0)
                    (vector-set! ls 12 (vector-ref ls 11))
                    (vector-set! ls 11 (lb-abs (- sty stx))))
                  0)
              (if (= (vector-ref ls 6) 1.0)
                  (begin
                    (vector-set! ls 13 (lb-min stx sty))
                    (vector-set! ls 14 (lb-max stx sty)))
                  (begin
                    (vector-set! ls 13 (+ nstp (* 1.1 (- nstp stx))))
                    (vector-set! ls 14 (+ nstp (* 4.0 (- nstp stx))))))
              (set! nstp (lb-max nstp stpmin))
              (set! nstp (lb-min nstp stpmax))
              (if (and (= (vector-ref ls 6) 1.0)
                       (or (or (<= nstp (vector-ref ls 13)) (>= nstp (vector-ref ls 14)))
                           (<= (- (vector-ref ls 14) (vector-ref ls 13)) (* xtol (vector-ref ls 14)))))
                  (set! nstp stx)
                  0)
              (vector-set! ls 15 nstp)))
          0)
      task)))

(define (lb-dot a b nv)
  (let ((acc 0.0))
    (do ((j 0 (+ j 1))) ((= j nv))
      (set! acc (+ acc (* (vector-ref a j) (vector-ref b j)))))
    acc))

;; row SLOT of the NV-wide memory MEM against V
(define (lb-dot-row mem slot v nv)
  (let ((acc 0.0))
    (do ((j 0 (+ j 1))) ((= j nv))
      (set! acc (+ acc (* (vector-ref mem (+ (* slot nv) j)) (vector-ref v j)))))
    acc))

(define (lb-dot-rows a ra b rb nv)
  (let ((acc 0.0))
    (do ((j 0 (+ j 1))) ((= j nv))
      (set! acc (+ acc (* (vector-ref a (+ (* ra nv) j)) (vector-ref b (+ (* rb nv) j))))))
    acc))

;; the largest entry of the projected gradient (L-BFGS-B's projgr): the
;; entry IB, bounded below by LBV, is cut to w - LBV when g pushes it down
(define (lb-projgr g w ib lbv nv)
  (let ((acc 0.0))
    (do ((j 0 (+ j 1))) ((= j nv))
      (let ((gj (vector-ref g j)))
        (let ((gp (if (and (= j ib) (>= gj 0.0)) (lb-min (- (vector-ref w j) lbv) gj) gj)))
          (let ((v (lb-abs gp)))
            (if (> v acc) (set! acc v) 0)))))
    acc))

;; H v into Q, Q holding v on entry: the two-loop recursion, H0 = I / theta
(define (lb-hv q smem ymem rho al theta col head m nv)
  (do ((ii 0 (+ ii 1))) ((= ii col))
    (let ((slot (remainder (+ head (- (- col 1) ii)) m)))
      (let ((a (* (vector-ref rho slot) (lb-dot-row smem slot q nv))))
        (vector-set! al slot a)
        (do ((j 0 (+ j 1))) ((= j nv))
          (vector-set! q j (- (vector-ref q j) (* a (vector-ref ymem (+ (* slot nv) j)))))))))
  (do ((j 0 (+ j 1))) ((= j nv)) (vector-set! q j (/ (vector-ref q j) theta)))
  (do ((ii 0 (+ ii 1))) ((= ii col))
    (let ((slot2 (remainder (+ head ii) m)))
      (let ((bb (* (vector-ref rho slot2) (lb-dot-row ymem slot2 q nv))))
        (do ((j 0 (+ j 1))) ((= j nv))
          (vector-set! q j (+ (vector-ref q j)
                              (* (- (vector-ref al slot2) bb) (vector-ref smem (+ (* slot2 nv) j)))))))))
  0)

;; v'B v, B the memory's BFGS matrix from theta I (the compact form's
;; matrix, which H inverts): the pairs applied oldest first, b_i = B_i s_i
;; built into BM and s_i'b_i into SB
(define (lb-vbv v smem ymem rho bm sb theta col head m nv)
  (do ((ii 0 (+ ii 1))) ((= ii col))
    (let ((si (remainder (+ head ii) m)))
      (do ((j 0 (+ j 1))) ((= j nv))
        (vector-set! bm (+ (* ii nv) j) (* theta (vector-ref smem (+ (* si nv) j)))))
      (do ((jj 0 (+ jj 1))) ((= jj ii))
        (let ((sj (remainder (+ head jj) m)))
          (let ((cb (/ (lb-dot-rows bm jj smem si nv) (vector-ref sb jj)))
                (cy (* (vector-ref rho sj) (lb-dot-rows ymem sj smem si nv))))
            (do ((j 0 (+ j 1))) ((= j nv))
              (vector-set! bm (+ (* ii nv) j)
                           (+ (- (vector-ref bm (+ (* ii nv) j)) (* cb (vector-ref bm (+ (* jj nv) j))))
                              (* cy (vector-ref ymem (+ (* sj nv) j)))))))))
      (vector-set! sb ii (lb-dot-rows bm ii smem si nv))))
  (let ((acc (* theta (lb-dot v v nv))))
    (do ((ii 0 (+ ii 1))) ((= ii col))
      (let ((si2 (remainder (+ head ii) m)))
        (let ((bv (lb-dot-row bm ii v nv))
              (yv (lb-dot-row ymem si2 v nv)))
          (set! acc (+ (- acc (/ (* bv bv) (vector-ref sb ii))) (* (vector-ref rho si2) (* yv yv)))))))
    acc))

;; The direction D from W.  Without a bound (IB < 0) -H g.  With the
;; entry IB bounded below by LBV, L-BFGS-B's two steps for that one
;; bounded entry: the generalized Cauchy point along -g fixes the entry
;; when it starts at the bound with g >= 0, or when the model's minimum
;; along -g, g'g / g'Bg, lies at or past the breakpoint (w - LBV) / g;
;; the subspace minimisation then minimises the model over the other
;; entries with the bounded one at the Cauchy point (by a multiplier: u =
;; -H g + lam H e, u_ib = delta), and otherwise is -H g projected onto
;; the bound -- kept if it still descends, else the step from the Cauchy
;; point cut back to the bound.
(define (lb-direction w g d q e smem ymem rho al bm sb theta col head m ib lbv nv)
  (do ((j 0 (+ j 1))) ((= j nv)) (vector-set! q j (vector-ref g j)))
  (lb-hv q smem ymem rho al theta col head m nv)
  (do ((j 0 (+ j 1))) ((= j nv)) (vector-set! d j (- 0.0 (vector-ref q j))))
  (if (>= ib 0)
      (let ((gs (vector-ref g ib)) (tl (- (vector-ref w ib) lbv))
            (fixed 0) (delta 0.0) (dtm 0.0))
        (if (and (<= tl 0.0) (>= gs 0.0))
            (set! fixed 1)
            (begin
              (set! dtm (/ (lb-dot g g nv) (lb-vbv g smem ymem rho bm sb theta col head m nv)))
              (if (and (> gs 0.0) (>= dtm (/ tl gs)))
                  (begin (set! fixed 1) (set! delta (- 0.0 tl)))
                  0)))
        (if (= fixed 1)
            (begin
              (do ((j 0 (+ j 1))) ((= j nv)) (vector-set! e j 0.0))
              (vector-set! e ib 1.0)
              (lb-hv e smem ymem rho al theta col head m nv)
              (let ((lam (/ (+ delta (vector-ref q ib)) (vector-ref e ib))))
                (do ((j 0 (+ j 1))) ((= j nv))
                  (vector-set! d j (+ (vector-ref d j) (* lam (vector-ref e j))))))
              (vector-set! d ib delta))
            (if (< (+ (vector-ref w ib) (vector-ref d ib)) lbv)
                ;; the projection onto the bound, if it still descends
                (let ((ddp (+ (- (lb-dot d g nv) (* (vector-ref d ib) gs)) (* (- lbv (vector-ref w ib)) gs))))
                  (if (> ddp 0.0)
                      ;; from the Cauchy point xcp = w - dtm g, along the
                      ;; step to the model's minimum, cut at the bound
                      (let ((dus (- (vector-ref d ib) (* (- 0.0 dtm) gs)))
                            (xcps (- (vector-ref w ib) (* dtm gs)))
                            (alpha 1.0))
                        (if (< dus 0.0)
                            (let ((temp2 (- lbv xcps)))
                              (if (>= temp2 0.0)
                                  (set! alpha 0.0)
                                  (if (< dus temp2) (set! alpha (/ temp2 dus)) 0)))
                            0)
                        (do ((j 0 (+ j 1))) ((= j nv))
                          (let ((xcpj (* (- 0.0 dtm) (vector-ref g j))))
                            (vector-set! d j (+ xcpj (* alpha (- (vector-ref d j) xcpj))))))
                        (if (< alpha 1.0) (vector-set! d ib (- lbv (vector-ref w ib))) 0))
                      (vector-set! d ib (- lbv (vector-ref w ib)))))
                0)))
      0)
  0)

(define (lbfgs kind w x y aux work out m maxiter pgtol ftol maxls ib lbv nv n p k)
  (let ((g (make-vector nv 0.0))
        (gold (make-vector nv 0.0))
        (d (make-vector nv 0.0))
        (t (make-vector nv 0.0))
        (q (make-vector nv 0.0))
        (e (make-vector nv 0.0))
        (smem (make-vector (* m nv) 0.0))
        (ymem (make-vector (* m nv) 0.0))
        (bm (make-vector (* m nv) 0.0))
        (rho (make-vector m 0.0))
        (sb (make-vector m 0.0))
        (al (make-vector m 0.0))
        (ls (make-vector 16 0.0))
        (cs (make-vector 8 0.0))
        (eps 2.220446049250313e-16)
        (iter 0) (col 0) (head 0) (theta 1.0) (nfg 0) (done 0))
    (let ((f (lbfgs-fg kind w g x y aux work n p k)))
      (set! nfg 1)
      (if (<= (lb-projgr g w ib lbv nv) pgtol) (set! done 1) 0)
      (do () ((= done 1))
        (lb-direction w g d q e smem ymem rho al bm sb theta col head m ib lbv nv)
        ;; the line search from t = w along d
        (do ((j 0 (+ j 1))) ((= j nv))
          (vector-set! t j (vector-ref w j))
          (vector-set! gold j (vector-ref g j)))
        (let ((fold f)
              (dnorm (sqrt (lb-dot d d nv)))
              (gdold (lb-dot g d nv))
              (stpmx 1e10)
              (gd 0.0) (task 0) (ifun 0) (fail 0))
          ;; the longest step the bound allows (1 on the first iteration)
          (if (>= ib 0)
              (if (= iter 0)
                  (set! stpmx 1.0)
                  (if (< (vector-ref d ib) 0.0)
                      (let ((a2 (- lbv (vector-ref w ib))))
                        (if (>= a2 0.0)
                            (set! stpmx 0.0)
                            (if (< (* (vector-ref d ib) stpmx) a2) (set! stpmx (/ a2 (vector-ref d ib))) 0)))
                      0))
              0)
          (if (>= gdold 0.0)
              (set! fail 1)
              (begin
                (lb-search-start ls f gdold (if (= iter 0) (lb-min (/ 1.0 dnorm) stpmx) 1.0) 0.0 stpmx 0.001)
                (do () ((or (= fail 1) (not (= task 0))))
                  (set! ifun (+ ifun 1))
                  (if (> ifun maxls)
                      (set! fail 1)
                      (let ((stp (vector-ref ls 15)))
                        (do ((j 0 (+ j 1))) ((= j nv))
                          (vector-set! w j (+ (vector-ref t j) (* stp (vector-ref d j)))))
                        (set! f (lbfgs-fg kind w g x y aux work n p k))
                        (set! nfg (+ nfg 1))
                        (set! gd (lb-dot g d nv))
                        (set! task (lb-search-step ls cs f gd 0.001 0.9 0.1 0.0 stpmx)))))))
          (if (= fail 1)
              ;; back to t; restart from -g, or stop if that was -g already
              (begin
                (do ((j 0 (+ j 1))) ((= j nv))
                  (vector-set! w j (vector-ref t j))
                  (vector-set! g j (vector-ref gold j)))
                (set! f fold)
                (if (= col 0)
                    (set! done 1)
                    (begin (set! col 0) (set! head 0) (set! theta 1.0))))
              (let ((stp2 (vector-ref ls 15)))
                (set! iter (+ iter 1))
                (if (>= iter maxiter) (set! done 1) 0)
                (if (<= (lb-projgr g w ib lbv nv) pgtol) (set! done 1) 0)
                (if (<= (- fold f) (* ftol (lb-max (lb-max (lb-abs fold) (lb-abs f)) 1.0))) (set! done 1) 0)
                (if (= done 0)
                    (let ((dr (* (- gd gdold) stp2))
                          (ddum (* (- 0.0 gdold) stp2)))
                      (if (> dr (* eps ddum))
                          (begin
                            (let ((slot3 (if (< col m) (remainder (+ head col) m) head)))
                              (let ((rr 0.0))
                                (do ((j 0 (+ j 1))) ((= j nv))
                                  (let ((yj (- (vector-ref g j) (vector-ref gold j))))
                                    (vector-set! smem (+ (* slot3 nv) j) (* stp2 (vector-ref d j)))
                                    (vector-set! ymem (+ (* slot3 nv) j) yj)
                                    (set! rr (+ rr (* yj yj)))))
                                (vector-set! rho slot3 (/ 1.0 dr))
                                (set! theta (/ rr dr))
                                (if (< col m) (set! col (+ col 1)) (set! head (remainder (+ head 1) m)))))
                            0)
                          0))
                    0)))))
      (vector-set! out 0 f)
      (vector-set! out 1 (exact->inexact nfg))
      iter)))

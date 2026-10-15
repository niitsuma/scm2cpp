;;;; Least angle regression over the Gram matrix, whole: scikit-learn's
;;;; _lars_path_solver with a Gram (what Lars and LassoLars run for
;;;; n > p), for method "lar" and "lasso", written out in the subset.
;;;;
;;;; COV is X'y and G is X'X (both overwritten as the solver permutes
;;;; them).  Each step takes the largest |correlation| C; stops when
;;;; C / NSAMPLES falls to ALPHAMIN (interpolating the last step back to
;;;; it); adds the variable of C to the active set -- swapped to the
;;;; front of G and COV, the Cholesky factor L of the active Gram block
;;;; grown by a row, the variable dropped again if its pivot falls below
;;;; 1e-7; solves L L' w = sign for the equiangular direction, scaled
;;;; by AA = 1 / sqrt(w . sign); steps along it by the smallest positive
;;;; gamma at which another variable's correlation catches up (the
;;;; inactive correlations' changes rounded to 15 decimals, as
;;;; np.around does) or, for "lasso", at which an active coefficient
;;;; crosses zero, in which case that variable leaves: L loses its row
;;;; by Givens rotations (scikit-learn's cholesky_delete, BLAS drotg and
;;;; drot), G its row and column by adjacent swaps, and its correlation
;;;; is recomputed from the saved X'y and X'X.  At most MAXITER steps.
;;;;
;;;; METHOD is 0 for "lar", 1 for "lasso".  COEF gets the coefficients
;;;; in the original order.  Returns the number of steps (n_iter_).
;;;;
;;;;[ja] Gram 行列の上の最小角回帰全体: scikit-learn の _lars_path_solver
;;;;[ja] (Gram あり、n > p で Lars と LassoLars が走らせるもの)を "lar" と
;;;;[ja] "lasso" についてそのままサブセットで書いたもの。相関の最大を取り、
;;;;[ja] C / NSAMPLES が ALPHAMIN に達したら補間して終了、変数を作業集合に加え
;;;;[ja] (G と COV の先頭へ、コレスキー因子を 1 行伸ばす)、等角方向を解き、
;;;;[ja] 他の変数の相関が追いつくか("lasso" では係数が 0 を横切る)最小の歩幅で
;;;;[ja] 進む。"lasso" で外す変数は Givens 回転でコレスキー因子から除き、相関を
;;;;[ja] 保存した X'y と X'X から計算し直す。METHOD は 0 が "lar"、1 が "lasso"。

;; the smallest positive value among the M values v[0..m), or 1.79e308
;; (scikit-learn's min_pos)
(define (min-pos v m)
  (let ((r 1.7976931348623157e308))
    (do ((i 0 (+ i 1))) ((= i m))
      (let ((x (vector-ref v i)))
        (if (and (> x 0.0) (< x r)) (set! r x) 0)))
    r))

;; round half to even, as np.around rounds
(define (round-even y)
  (let ((r (floor y)))
    (let ((d (- y r)))
      (if (> d 0.5) (+ r 1.0)
          (if (< d 0.5) r
              (if (= (* 2.0 (floor (* 0.5 r))) r) r (+ r 1.0)))))))

;; remove row and column GO from the N x N Cholesky factor L (row stride
;; K), scikit-learn's cholesky_delete: shift the rows up, then restore
;; the triangle with plane rotations (drotg, drot)
(define (cholesky-delete l go n k)
  (do ((i go (+ i 1))) ((>= i (- n 1)))
    (do ((j 0 (+ j 1))) ((= j (+ i 2)))
      (vector-set! l (+ (* i k) j) (vector-ref l (+ (* (+ i 1) k) j)))))
  (do ((i go (+ i 1))) ((>= i (- n 1)))
    (let ((a (vector-ref l (+ (* i k) i)))
          (b (vector-ref l (+ (* i k) (+ i 1)))))
      (let ((aa (if (< a 0.0) (- 0.0 a) a)) (ab (if (< b 0.0) (- 0.0 b) b)))
        (let ((roe (if (> aa ab) a b)) (scale (+ aa ab)))
          (let ((r (if (= scale 0.0) 0.0
                       (* (if (< roe 0.0) -1.0 1.0)
                          (* scale (sqrt (+ (* (/ a scale) (/ a scale)) (* (/ b scale) (/ b scale)))))))))
            (let ((c (if (= scale 0.0) 1.0 (/ a r)))
                  (s (if (= scale 0.0) 0.0 (/ b r))))
              (let ((cc (if (< r 0.0) (- 0.0 c) c))
                    (ss (if (< r 0.0) (- 0.0 s) s)))
                (vector-set! l (+ (* i k) i) (if (< r 0.0) (- 0.0 r) r))
                (vector-set! l (+ (* i k) (+ i 1)) 0.0)
                ;; rows i+1 .. n-1 of columns i and i+1
                (do ((t (+ i 1) (+ t 1))) ((>= t n))
                  (let ((x (vector-ref l (+ (* t k) i)))
                        (y (vector-ref l (+ (* t k) (+ i 1)))))
                    (vector-set! l (+ (* t k) i) (+ (* cc x) (* ss y)))
                    (vector-set! l (+ (* t k) (+ i 1)) (- (* cc y) (* ss x))))))))))))
  0)

;; swap rows and columns A and B of the P x P matrix G
(define (swap-rc g a b p)
  (do ((j 0 (+ j 1))) ((= j p))
    (let ((rv (vector-ref g (+ (* a p) j))))
      (vector-set! g (+ (* a p) j) (vector-ref g (+ (* b p) j)))
      (vector-set! g (+ (* b p) j) rv)))
  (do ((j 0 (+ j 1))) ((= j p))
    (let ((cv (vector-ref g (+ (* j p) a))))
      (vector-set! g (+ (* j p) a) (vector-ref g (+ (* j p) b)))
      (vector-set! g (+ (* j p) b) cv)))
  0)

(define (lars g cov coef nsamples alphamin method maxiter eps p)
  (let ((g0 (make-vector (* p p) 0.0))
        (cov0 (make-vector p 0.0))
        (cbuf (make-vector p 0.0))
        (index (make-vector p 0))
        (active (make-vector p 0))
        (sign (make-vector p 0.0))
        (kmax (if (< maxiter p) maxiter p))
        (prev (make-vector p 0.0))
        (dir (make-vector p 0.0))
        (ls (make-vector p 0.0))
        (zz (make-vector p 0.0))
        (ratio (make-vector p 0.0))
        (idx (make-vector p 0))
        (dropv (make-vector p 0))
        (cs 0) (na 0) (niter 0) (drop 0) (done 0)
        (alpha 0.0) (prevalpha 0.0)
        (tiny32 1.1754943508222875e-38) (eqtol 1.1920928955078125e-07))
    (let ((l (make-vector (* kmax kmax) 0.0)))
      (do ((t 0 (+ t 1))) ((= t (* p p))) (vector-set! g0 t (vector-ref g t)))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! cov0 j (vector-ref cov j))
        (vector-set! cbuf j (vector-ref cov j))
        (vector-set! index j j)
        (vector-set! coef j 0.0))
      (do () ((= done 1))
        (let ((clen (- p cs)) (cidx 0) (cval 0.0) (cabs 0.0))
          ;; C: the largest |correlation| among the inactive
          (do ((t 0 (+ t 1))) ((= t clen))
            (let ((v (vector-ref cbuf (+ cs t))))
              (let ((av (if (< v 0.0) (- 0.0 v) v)))
                (if (> av cabs) (begin (set! cabs av) (set! cidx t) (set! cval v)) 0))))
          (set! alpha (/ cabs (* 1.0 nsamples)))
          (if (<= alpha (+ alphamin eqtol))
              (begin
                (if (> (if (< (- alpha alphamin) 0.0) (- alphamin alpha) (- alpha alphamin)) eqtol)
                    (begin
                      (if (> niter 0)
                          (let ((ss (/ (- prevalpha alphamin) (- prevalpha alpha))))
                            (do ((j 0 (+ j 1))) ((= j p))
                              (vector-set! coef j (+ (vector-ref prev j)
                                                     (* ss (- (vector-ref coef j) (vector-ref prev j)))))))
                          0)
                      (set! alpha alphamin))
                    0)
                (set! done 1))
              (if (or (>= niter maxiter) (>= na p))
                  (set! done 1)
                  (begin
                  (let ((degenerate 0))
                    (if (= drop 0)
                        ;; the variable of C joins the active set
                        (let ((m na) (nn (+ cidx na)))
                          (vector-set! sign na (if (> cval 0.0) 1.0 (if (< cval 0.0) -1.0 0.0)))
                          (let ((tc (vector-ref cbuf (+ cs cidx))))
                            (vector-set! cbuf (+ cs cidx) (vector-ref cbuf cs))
                            (vector-set! cbuf cs tc))
                          (let ((ti (vector-ref index nn)))
                            (vector-set! index nn (vector-ref index m))
                            (vector-set! index m ti))
                          (set! cs (+ cs 1))
                          (swap-rc g m nn p)
                          (let ((c (vector-ref g (+ (* na p) na))) (v 0.0))
                            (do ((i 0 (+ i 1))) ((= i na))
                              (let ((t (vector-ref g (+ (* na p) i))))
                                (do ((s 0 (+ s 1))) ((= s i))
                                  (set! t (- t (* (vector-ref l (+ (* i kmax) s)) (vector-ref l (+ (* na kmax) s))))))
                                (let ((li (/ t (vector-ref l (+ (* i kmax) i)))))
                                  (vector-set! l (+ (* na kmax) i) li)
                                  (set! v (+ v (* li li))))))
                            (let ((dd (sqrt (if (< (- c v) 0.0) (- v c) (- c v)))))
                             (let ((dg (if (> dd (* 1.0 eps)) dd (* 1.0 eps))))
                              (vector-set! l (+ (* na kmax) na) dg)
                              (if (< dg 1e-7)
                                  ;; degenerate: the correlation zeroed and put back
                                  (begin
                                    (set! cs (- cs 1))
                                    (vector-set! cbuf cs 0.0)
                                    (let ((tc (vector-ref cbuf (+ cs cidx))))
                                      (vector-set! cbuf (+ cs cidx) (vector-ref cbuf cs))
                                      (vector-set! cbuf cs tc))
                                    (set! degenerate 1))
                                  (begin
                                    (vector-set! active na (vector-ref index na))
                                    (set! na (+ na 1))))))))
                        #f)
                    (if (= degenerate 0)
                        (if (and (= method 1) (> niter 0) (< prevalpha alpha))
                            (set! done 1)
                            (begin
                            (let ((aa 0.0) (clen2 (- p cs)))
                              ;; least squares: L L' w = sign
                              (do ((i 0 (+ i 1))) ((= i na))
                                (let ((t (vector-ref sign i)))
                                  (do ((s 0 (+ s 1))) ((= s i))
                                    (set! t (- t (* (vector-ref l (+ (* i kmax) s)) (vector-ref zz s)))))
                                  (vector-set! zz i (/ t (vector-ref l (+ (* i kmax) i))))))
                              (do ((ii 0 (+ ii 1))) ((= ii na))
                                (let ((i (- (- na 1) ii)))
                                  (let ((t (vector-ref zz i)))
                                    (do ((s (+ i 1) (+ s 1))) ((>= s na))
                                      (set! t (- t (* (vector-ref l (+ (* s kmax) i)) (vector-ref ls s)))))
                                    (vector-set! ls i (/ t (vector-ref l (+ (* i kmax) i)))))))
                              (if (and (= na 1) (= (vector-ref ls 0) 0.0))
                                  (begin (vector-set! ls 0 1.0) (set! aa 1.0))
                                  (let ((sm 0.0))
                                    (do ((i 0 (+ i 1))) ((= i na))
                                      (set! sm (+ sm (* (vector-ref ls i) (vector-ref sign i)))))
                                    (set! aa (/ 1.0 (sqrt sm)))
                                    (do ((i 0 (+ i 1))) ((= i na))
                                      (vector-set! ls i (* aa (vector-ref ls i))))))
                              ;; the inactive correlations' change along the direction
                              (do ((t 0 (+ t 1))) ((= t clen2))
                                (let ((acc 0.0))
                                  (do ((i 0 (+ i 1))) ((= i na))
                                    (set! acc (+ acc (* (vector-ref g (+ (* i p) (+ na t))) (vector-ref ls i)))))
                                  (vector-set! dir t (/ (round-even (* acc 1e15)) 1e15))))
                              (do ((t 0 (+ t 1))) ((= t clen2))
                                (vector-set! ratio t (/ (- cabs (vector-ref cbuf (+ cs t)))
                                                        (+ (- aa (vector-ref dir t)) tiny32))))
                              (let ((gfirst (min-pos ratio clen2)))
                                (do ((t 0 (+ t 1))) ((= t clen2))
                                  (vector-set! ratio t (/ (+ cabs (vector-ref cbuf (+ cs t)))
                                                          (+ (+ aa (vector-ref dir t)) tiny32))))
                                (let ((gsecond (min-pos ratio clen2)))
                                  (let ((gam (if (< (if (< gfirst gsecond) gfirst gsecond) (/ cabs aa)) (if (< gfirst gsecond) gfirst gsecond) (/ cabs aa)))
                                        (nidx 0))
                                    ;; a coefficient crossing zero
                                    (set! drop 0)
                                    (do ((i 0 (+ i 1))) ((= i na))
                                      (vector-set! zz i (/ (- 0.0 (vector-ref coef (vector-ref active i)))
                                                           (+ (vector-ref ls i) tiny32))))
                                    (let ((zpos (min-pos zz na)))
                                      (if (< zpos gam)
                                          (begin
                                            ;; the crossing indices, last first
                                            (do ((ii 0 (+ ii 1))) ((= ii na))
                                              (let ((i (- (- na 1) ii)))
                                                (if (= (vector-ref zz i) zpos)
                                                    (begin (vector-set! idx nidx i) (set! nidx (+ nidx 1)))
                                                    0)))
                                            (do ((r 0 (+ r 1))) ((= r nidx))
                                              (let ((i (vector-ref idx r)))
                                                (vector-set! sign i (- 0.0 (vector-ref sign i)))))
                                            (if (= method 1) (set! gam zpos) 0)
                                            (set! drop 1))
                                          0))
                                    (set! niter (+ niter 1))
                                    (set! prevalpha alpha)
                                    (do ((j 0 (+ j 1))) ((= j p))
                                      (vector-set! prev j (vector-ref coef j))
                                      (vector-set! coef j 0.0))
                                    (do ((i 0 (+ i 1))) ((= i na))
                                      (let ((a (vector-ref active i)))
                                        (vector-set! coef a (+ (vector-ref prev a) (* gam (vector-ref ls i))))))
                                    (do ((t 0 (+ t 1))) ((= t clen2))
                                      (vector-set! cbuf (+ cs t) (- (vector-ref cbuf (+ cs t)) (* gam (vector-ref dir t)))))
                                    ;; "lasso": the crossing variables leave
                                    (if (and (= drop 1) (= method 1))
                                        (begin
                                          (do ((r 0 (+ r 1))) ((= r nidx))
                                            (cholesky-delete l (vector-ref idx r) na kmax))
                                          (set! na (- na 1))
                                          (do ((r 0 (+ r 1))) ((= r nidx))
                                            (let ((ii (vector-ref idx r)))
                                              (let ((dropped (vector-ref active ii)))
                                                ;; active.pop(ii), the dropped index kept for its correlation
                                                (do ((i ii (+ i 1))) ((>= i na))
                                                  (vector-set! active i (vector-ref active (+ i 1))))
                                                (vector-set! dropv r dropped))))
                                          (do ((r 0 (+ r 1))) ((= r nidx))
                                            (let ((ii (vector-ref idx r)))
                                              (do ((i ii (+ i 1))) ((>= i na))
                                                (let ((ti (vector-ref index i)))
                                                  (vector-set! index i (vector-ref index (+ i 1)))
                                                  (vector-set! index (+ i 1) ti))
                                                (swap-rc g i (+ i 1) p))))
                                          ;; the dropped correlations, from the saved X'y and X'X, in front
                                          (do ((rr 0 (+ rr 1))) ((= rr nidx))
                                            (let ((r (- (- nidx 1) rr)))
                                              (let ((d (vector-ref dropv r)))
                                                (let ((t (vector-ref cov0 d)))
                                                  (do ((j 0 (+ j 1))) ((= j p))
                                                    (set! t (- t (* (vector-ref g0 (+ (* d p) j)) (vector-ref coef j)))))
                                                  (set! cs (- cs 1))
                                                  (vector-set! cbuf cs t)))))
                                          ;; sign_active: the entries removed, zeros appended
                                          (do ((r 0 (+ r 1))) ((= r nidx))
                                            (let ((ii (vector-ref idx r)))
                                              (do ((i ii (+ i 1))) ((>= i (- p 1)))
                                                (vector-set! sign i (vector-ref sign (+ i 1))))
                                              (vector-set! sign (- p 1) 0.0))))
                                        0)))))))
                        0))))))))
      niter))

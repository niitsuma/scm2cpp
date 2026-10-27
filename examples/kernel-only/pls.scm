;;;; Partial least squares and CCA over the cross-product matrices:
;;;; scikit-learn's _PLS (PLSRegression, PLSCanonical, CCA) written out in
;;;; the subset, with the n x p and n x q blocks never touched.
;;;;
;;;; NIPALS only ever multiplies the blocks by a weight vector, and every
;;;; such product is a product of Cxx = X'X, Cxy = X'Y or Cyy = Y'Y: the
;;;; Y score is Y c for a coefficient vector c, X'(Y c) = Cxy c, and
;;;; Y'(X w) = Cyx w.  The deflations are rank-one updates of the three:
;;;; with a = Cxx w (= X't), b = Cxy' w (= Y't) and s2 = w'Cxx w (= t't),
;;;;   X <- X - t p'           Cxx <- Cxx - a a' / s2
;;;;   regression, Y <- Y - t q'   Cyy <- Cyy - b b' / s2,  Cxy <- Cxy - a b' / s2
;;;;   canonical, Y <- Y - u q'    from Y's score u = Y yw / y_ss in the same way.
;;;; So the n rows are read once, by the caller's products, and a
;;;; component costs O(p^2 + p q + q^2) per power iteration.  Mode B
;;;; (CCA) takes pinv(X) y = Cxx^+ X'y with Cxx^+ from its eigenproblem,
;;;; cut where scikit-learn's _pinv2_old cuts the singular values.
;;;;

(include "sym-eigen.scm")
(include "sym-svd.scm")

;; P (m x m) = A^+ for A symmetric positive semi-definite (m x m, kept):
;; eigenvalues under (1e6 eps sqrt(lam_max))^2 are dropped, as
;; _pinv2_old drops the singular values of the block whose Gram A is,
;; and under 1e3 eps lam_max too: a deflated block has lost a rank
;; exactly, which its SVD shows as a singular value near eps s_max but
;; its Gram as an eigenvalue near eps lam_max -- sqrt(eps) relative as a
;; singular value, above _pinv2_old's cut -- and dividing by it ruined
;; the second component.  So singular values under about 5e-7 s_max go
;; (a block conditioned past 2e6), where scikit-learn would keep them.
(define (pls-pinv a pv m)
  (let ((w (make-vector (* m m) 0.0))
        (v (make-vector (* m m) 0.0))
        (vs (make-vector (* m m) 0.0))
        (ev (make-vector m 0.0))
        (e (make-vector m 0.0))
        (top 0.0))
    (do ((s 0 (+ s 1))) ((= s (* m m))) (vector-set! w s (vector-ref a s)))
    (sym-eigen w v ev e m)
    (do ((k 0 (+ k 1))) ((= k m))
      (if (> (vector-ref ev k) top) (set! top (vector-ref ev k)) 0))
    (let ((cut (* (* 1e6 2.220446049250313e-16) (sqrt top)))
          (lo (* (* 1e3 2.220446049250313e-16) top)))
      ;; VS = V diag(1/lam) over the kept values, then P = VS V' (a dgemm)
      (do ((i 0 (+ i 1))) ((= i m))
        (do ((k 0 (+ k 1))) ((= k m))
          (let ((lam (vector-ref ev k)))
            (vector-set! vs (+ (* i m) k)
                         (if (> lam lo)
                             (if (> (sqrt lam) cut) (/ (vector-ref v (+ (* i m) k)) lam) 0.0)
                             0.0)))))
      (with-arrays ((vs (m m)) (v (m m)) (pv (m m)))
        (array-set! pv (matmul vs (transpose v)))))
    0))

;; y = A x for A (m x n), x of n
(define (pls-mv a x y m n)
  (do ((i 0 (+ i 1))) ((= i m))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j n))
        (set! acc (+ acc (* (vector-ref a (+ (* i n) j)) (vector-ref x j)))))
      (vector-set! y i acc)))
  0)

;; y = A' x for A (m x n), x of m
(define (pls-mtv a x y m n)
  (do ((j 0 (+ j 1))) ((= j n))
    (let ((acc 0.0))
      (do ((i 0 (+ i 1))) ((= i m))
        (set! acc (+ acc (* (vector-ref a (+ (* i n) j)) (vector-ref x i)))))
      (vector-set! y j acc)))
  0)

(define (pls-dot x y m)
  (let ((acc 0.0))
    (do ((i 0 (+ i 1))) ((= i m)) (set! acc (+ acc (* (vector-ref x i) (vector-ref y i)))))
    acc))

;; The whole fit.  CXX (p x p), CXY (p x q) and CYY (q x q) are the
;; centred (and scaled) cross products, deflated in place.  MODE is 0
;; for A, 1 for B; CANON 1 for canonical deflation (and normalised Y
;; weights), 0 for regression; ALGO 0 for NIPALS, 1 for the SVD of
;; Cxy.  XW (p x k), YW (q x k), XL (p x k) and YL (q x k) get the
;; weights and loadings as columns, NITER the power iterations per
;; component.  Returns the components found: fewer than K when the Y
;; residual is constant, as scikit-learn stops then.
(define (pls-fit cxx cxy cyy xw yw xl yl niter p q k mode canon algo maxit tol)
  (let ((c (make-vector q 0.0))
        (w (make-vector p 0.0))
        (wold (make-vector p 0.0))
        (yv (make-vector q 0.0))
        (a (make-vector p 0.0))
        (b (make-vector q 0.0))
        (g (make-vector p 0.0))
        (cy (make-vector q 0.0))
        (tmp (make-vector p 0.0))
        (px (make-vector (* p p) 0.0))
        (py (make-vector (* q q) 0.0))
        (cm (make-vector (* p q) 0.0))
        (uu (make-vector (* p p) 0.0))
        (ss (make-vector p 0.0))
        (vt (make-vector (* p q) 0.0))
        (eps 2.220446049250313e-16)
        (found 0)
        (stop 0))
    (do ((comp 0 (+ comp 1))) ((or (= comp k) (= stop 1)))
      ;; columns of Y whose residual is all but zero are zeroed
      (do ((j 0 (+ j 1))) ((= j q))
        (if (< (vector-ref cyy (+ (* j q) j)) (* 100.0 (* eps eps)))
            (begin
              (do ((i 0 (+ i 1))) ((= i q))
                (vector-set! cyy (+ (* j q) i) 0.0)
                (vector-set! cyy (+ (* i q) j) 0.0))
              (do ((i 0 (+ i 1))) ((= i p)) (vector-set! cxy (+ (* i q) j) 0.0)))
            0))
      (let ((first -1))
        (do ((j 0 (+ j 1))) ((= j q))
          (if (and (< first 0) (> (vector-ref cyy (+ (* j q) j)) (* eps eps))) (set! first j) 0))
        (if (< first 0)
            (set! stop 1)
            (begin
              (if (= algo 1)
                  ;; the leading singular pair of Cxy
                  (let ((r (if (< p q) p q)))
                    (do ((s 0 (+ s 1))) ((= s (* p q))) (vector-set! cm s (vector-ref cxy s)))
                    (sym-svd cm uu ss vt p q)
                    (do ((i 0 (+ i 1))) ((= i p)) (vector-set! w i (vector-ref uu (* i r))))
                    (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yv j (vector-ref vt j)))
                    (vector-set! niter comp 0))
                  (begin
                    (if (= mode 1) (begin (pls-pinv cxx px p) (pls-pinv cyy py q)) 0)
                    (do ((j 0 (+ j 1))) ((= j q)) (vector-set! c j (if (= j first) 1.0 0.0)))
                    (do ((i 0 (+ i 1))) ((= i p)) (vector-set! wold i 100.0))
                    (let ((done 0))
                      (do ((it 0 (+ it 1))) ((or (= done 1) (= it maxit)))
                        ;; x weights: X'(Y c), or pinv(X) (Y c) in mode B
                        (pls-mv cxy c g p q)
                        (if (= mode 1)
                            (pls-mv px g w p p)
                            (begin
                              (pls-mv cyy c cy q q)
                              (let ((uu2 (pls-dot c cy q)))
                                (do ((i 0 (+ i 1))) ((= i p)) (vector-set! w i (/ (vector-ref g i) uu2))))))
                        (let ((nw (+ (sqrt (pls-dot w w p)) eps)))
                          (do ((i 0 (+ i 1))) ((= i p)) (vector-set! w i (/ (vector-ref w i) nw))))
                        ;; y weights: Y'(X w), or pinv(Y) (X w)
                        (pls-mtv cxy w b p q)
                        (if (= mode 1)
                            (pls-mv py b yv q q)
                            (begin
                              (pls-mv cxx w a p p)
                              (let ((s2 (pls-dot w a p)))
                                (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yv j (/ (vector-ref b j) s2))))))
                        (if (= canon 1)
                            (let ((ny (+ (sqrt (pls-dot yv yv q)) eps)))
                              (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yv j (/ (vector-ref yv j) ny))))
                            0)
                        (let ((yy (+ (pls-dot yv yv q) eps)))
                          (do ((j 0 (+ j 1))) ((= j q)) (vector-set! c j (/ (vector-ref yv j) yy))))
                        (let ((d 0.0))
                          (do ((i 0 (+ i 1))) ((= i p))
                            (set! d (+ d (* (- (vector-ref w i) (vector-ref wold i))
                                            (- (vector-ref w i) (vector-ref wold i))))))
                          (if (or (< d tol) (= q 1)) (set! done 1) 0))
                        (do ((i 0 (+ i 1))) ((= i p)) (vector-set! wold i (vector-ref w i)))
                        (vector-set! niter comp (+ it 1))))))
              ;; svd_flip on the pair: the x weight of largest magnitude positive
              (let ((big 0) (bv -1.0))
                (do ((i 0 (+ i 1))) ((= i p))
                  (let ((aa (if (< (vector-ref w i) 0.0) (- 0.0 (vector-ref w i)) (vector-ref w i))))
                    (if (> aa bv) (begin (set! bv aa) (set! big i)) 0)))
                (if (< (vector-ref w big) 0.0)
                    (begin
                      (do ((i 0 (+ i 1))) ((= i p)) (vector-set! w i (- 0.0 (vector-ref w i))))
                      (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yv j (- 0.0 (vector-ref yv j)))))
                    0))
              ;; loadings and the deflations, in the cross products
              (pls-mv cxx w a p p)
              (pls-mtv cxy w b p q)
              (let ((s2 (pls-dot w a p))
                    (yss (if (= canon 1) 1.0 (pls-dot yv yv q))))
                (do ((i 0 (+ i 1))) ((= i p)) (vector-set! xl (+ (* i k) comp) (/ (vector-ref a i) s2)))
                (if (= canon 1)
                    ;; Y's score u = Y yw / yss: Y'u = Cyy yw / yss, X'u = Cxy yw / yss
                    (begin
                      (pls-mv cyy yv cy q q)
                      (pls-mv cxy yv g p q)
                      (let ((uu3 (/ (pls-dot yv cy q) (* yss yss)))
                            (h (/ (pls-dot w g p) yss)))
                        (do ((j 0 (+ j 1))) ((= j q))
                          (vector-set! yl (+ (* j k) comp) (/ (/ (vector-ref cy j) yss) uu3)))
                        ;; X'u after X's deflation: g/yss - p h, p = a / s2
                        (do ((i 0 (+ i 1))) ((= i p))
                          (vector-set! tmp i (- (/ (vector-ref g i) yss) (* (/ (vector-ref a i) s2) h))))
                        (do ((i 0 (+ i 1))) ((= i p))
                          (do ((j 0 (+ j 1))) ((= j q))
                            (vector-set! cxy (+ (* i q) j)
                                         (- (- (vector-ref cxy (+ (* i q) j))
                                               (/ (* (vector-ref a i) (vector-ref b j)) s2))
                                            (* (vector-ref tmp i) (vector-ref yl (+ (* j k) comp)))))))
                        (do ((i 0 (+ i 1))) ((= i q))
                          (do ((j 0 (+ j 1))) ((= j q))
                            (vector-set! cyy (+ (* i q) j)
                                         (- (vector-ref cyy (+ (* i q) j))
                                            (/ (* (/ (vector-ref cy i) yss) (/ (vector-ref cy j) yss)) uu3)))))))
                    (begin
                      (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yl (+ (* j k) comp) (/ (vector-ref b j) s2)))
                      (do ((i 0 (+ i 1))) ((= i p))
                        (do ((j 0 (+ j 1))) ((= j q))
                          (vector-set! cxy (+ (* i q) j)
                                       (- (vector-ref cxy (+ (* i q) j)) (/ (* (vector-ref a i) (vector-ref b j)) s2)))))
                      (do ((i 0 (+ i 1))) ((= i q))
                        (do ((j 0 (+ j 1))) ((= j q))
                          (vector-set! cyy (+ (* i q) j)
                                       (- (vector-ref cyy (+ (* i q) j)) (/ (* (vector-ref b i) (vector-ref b j)) s2)))))))
                (do ((i 0 (+ i 1))) ((= i p))
                  (do ((j 0 (+ j 1))) ((= j p))
                    (vector-set! cxx (+ (* i p) j)
                                 (- (vector-ref cxx (+ (* i p) j)) (/ (* (vector-ref a i) (vector-ref a j)) s2))))))
              (do ((i 0 (+ i 1))) ((= i p)) (vector-set! xw (+ (* i k) comp) (vector-ref w i)))
              (do ((j 0 (+ j 1))) ((= j q)) (vector-set! yw (+ (* j k) comp) (vector-ref yv j)))
              (set! found (+ found 1))))))
    found))

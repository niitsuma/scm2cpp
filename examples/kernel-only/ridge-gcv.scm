;;;; Ridge's leave-one-out errors at many alphas from one eigenproblem:
;;;; scikit-learn's RidgeCV with cv=None (generalised cross-validation),
;;;; written out in the subset.
;;;;
;;;; With the centred design Xc and the hat matrix
;;;; H(a) = Xc (Xc'Xc + a I)^-1 Xc' (plus 11'/n, the unpenalised
;;;; intercept, when one is fitted), the leave-one-out residual is
;;;; e_i = (y_i - yhat_i) / (1 - H_ii): no refit per row.  Any Z with
;;;; H(a) = Z diag(1 / (lam + a)) Z' serves, and two give it:
;;;;
;;;;   primal (n > p)  Xc'Xc = V diag(lam) V', Z = Xc V          (n x p)
;;;;   dual   (p >= n) Xc Xc' = Q diag(mu) Q', Z = Q diag(sqrt mu) (n x n)
;;;;
;;;; and then, for every alpha at once, with W[k,a] = 1 / (lam_k + a_a),
;;;; diag H = (Z o Z) W and yhat = Z (R o W) for R = Z' y: two products
;;;; per target, whatever the number of alphas.  sym-eigen is LAPACK's
;;;; dsyevd under --blas, the products dgemm.
;;;;
;;;;[ja] RidgeCV(cv=None、一般化交差検証)をサブセットで書いたもの。中心化した
;;;;[ja] Xc の帽子行列 H(a) = Xc (Xc'Xc + a I)^-1 Xc'(切片ありなら + 11'/n)で、
;;;;[ja] 1 個抜きの残差は e_i = (y_i - yhat_i) / (1 - H_ii)。H = Z diag(1/(lam+a)) Z'
;;;;[ja] となる Z を 1 回の固有分解で作り(n > p なら Xc'Xc、p >= n なら Xc Xc')、
;;;;[ja] 全 alpha の diag H と yhat を行列積 2 回で出す。

(include "sym-eigen.scm")

;; G (p x p) is Xc'Xc, destroyed.  V gets its eigenvectors as columns,
;; LAM the eigenvalues (negative ones set to zero), Z = (X - 1 xm') V,
;; R = Z' YC for the t centred targets YC (n x t).  XM is the column
;; means of X (zero when X is already centred).
(define (ridge-gcv-primal x xm yc g v lam z r n p t)
  (let ((e (make-vector p 0.0))
        (s (make-vector p 0.0)))
    (sym-eigen g v lam e p)
    (do ((k 0 (+ k 1))) ((= k p))
      (if (< (vector-ref lam k) 0.0) (vector-set! lam k 0.0) 0))
    (with-arrays ((x (n p)) (v (p p)) (z (n p)))
      (array-set! z (matmul x v)))
    ;; s = V' xm, taken off every row of X V
    (do ((k 0 (+ k 1))) ((= k p))
      (let ((acc 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (set! acc (+ acc (* (vector-ref xm j) (vector-ref v (+ (* j p) k))))))
        (vector-set! s k acc)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((k 0 (+ k 1))) ((= k p))
        (vector-set! z (+ (* i p) k) (- (vector-ref z (+ (* i p) k)) (vector-ref s k)))))
    (with-arrays ((z (n p)) (yc (n t)) (r (p t)))
      (array-set! r (matmul (transpose z) yc)))
    0))

;; K (n x n) is Xc Xc', destroyed.  Q gets its eigenvectors as columns,
;; MU the eigenvalues (negative ones set to zero), Z = Q diag(sqrt mu),
;; R = Z' YC.
(define (ridge-gcv-dual k q mu yc z r n t)
  (let ((e (make-vector n 0.0)))
    (sym-eigen k q mu e n)
    (do ((c 0 (+ c 1))) ((= c n))
      (if (< (vector-ref mu c) 0.0) (vector-set! mu c 0.0) 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((c 0 (+ c 1))) ((= c n))
        (vector-set! z (+ (* i n) c) (* (vector-ref q (+ (* i n) c)) (sqrt (vector-ref mu c))))))
    (with-arrays ((z (n n)) (yc (n t)) (r (n t)))
      (array-set! r (matmul (transpose z) yc)))
    0))

;; Z (n x m), LAM and R (m x t) from either of the above; ALPHAS na of
;; them; H0 is 1/n with an intercept, else 0.  MSE[a t + j] gets the mean
;; squared leave-one-out error of target j at alpha a; when STORE is 1,
;; LOO[(i t + j) na + a] gets each squared error (cv_results_'s layout).
(define (ridge-gcv-scan z lam r yc alphas h0 mse loo store n m t na)
  (let ((z2 (make-vector (* n m) 0.0))
        (w (make-vector (* m na) 0.0))
        (rw (make-vector (* m na) 0.0))
        (hd (make-vector (* n na) 0.0))
        (yh (make-vector (* n na) 0.0)))
    (do ((q 0 (+ q 1))) ((= q (* n m)))
      (vector-set! z2 q (* (vector-ref z q) (vector-ref z q))))
    (do ((k 0 (+ k 1))) ((= k m))
      (do ((a 0 (+ a 1))) ((= a na))
        (vector-set! w (+ (* k na) a) (/ 1.0 (+ (vector-ref lam k) (vector-ref alphas a))))))
    (with-arrays ((z2 (n m)) (w (m na)) (hd (n na)))
      (array-set! hd (matmul z2 w)))
    (do ((j 0 (+ j 1))) ((= j t))
      (do ((k 0 (+ k 1))) ((= k m))
        (do ((a 0 (+ a 1))) ((= a na))
          (vector-set! rw (+ (* k na) a) (* (vector-ref r (+ (* k t) j)) (vector-ref w (+ (* k na) a))))))
      (with-arrays ((z (n m)) (rw (m na)) (yh (n na)))
        (array-set! yh (matmul z rw)))
      (do ((a 0 (+ a 1))) ((= a na)) (vector-set! mse (+ (* a t) j) 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (do ((a 0 (+ a 1))) ((= a na))
          (let ((e (/ (- (vector-ref yc (+ (* i t) j)) (vector-ref yh (+ (* i na) a)))
                      (- (- 1.0 h0) (vector-ref hd (+ (* i na) a))))))
            (vector-set! mse (+ (* a t) j)
                         (+ (vector-ref mse (+ (* a t) j)) (/ (* e e) (exact->inexact n))))
            (if (= store 1) (vector-set! loo (+ (* (+ (* i t) j) na) a) (* e e)) 0)))))
    0))

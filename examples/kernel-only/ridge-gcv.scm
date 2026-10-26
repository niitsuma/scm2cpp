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
;;;; The dual does not form H: as alpha falls H tends to I there, and
;;;; both y - yhat and 1 - H_ii lose their digits.  It takes, as
;;;; scikit-learn does, G = Xc Xc' + 11' (the intercept's column, when
;;;; one is fitted) and e = c / diag G(a)^-1 for c = G(a)^-1 y and
;;;; G(a) = G + a I with the intercept's eigenvalue unpenalised:
;;;; diag G(a)^-1 = (Q o Q) W and c = Q (R o W), R = Q' y, with W's row
;;;; for the eigenvector nearest 1 set to zero.  Both are alpha times
;;;; the primal's, and nothing is subtracted.
;;;;
;;;;[ja] RidgeCV(cv=None、一般化交差検証)をサブセットで書いたもの。中心化した
;;;;[ja] Xc の帽子行列 H(a) = Xc (Xc'Xc + a I)^-1 Xc'(切片ありなら + 11'/n)で、
;;;;[ja] 1 個抜きの残差は e_i = (y_i - yhat_i) / (1 - H_ii)。H = Z diag(1/(lam+a)) Z'
;;;;[ja] となる Z を 1 回の固有分解で作り(n > p なら Xc'Xc、p >= n なら Xc Xc')、
;;;;[ja] 全 alpha の diag H と yhat を行列積 2 回で出す。双対は H を作らず
;;;;[ja] (alpha が小さいと H -> I で y - yhat も 1 - H_ii も桁落ちする)、
;;;;[ja] scikit-learn と同じく G = Xc Xc' + 11' の固有分解から c = G(a)^-1 y と
;;;;[ja] diag G(a)^-1 を出して e = c / diag G(a)^-1(切片の固有ベクトルは重み 0)。

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

;; K (n x n) is Xc Xc', plus 1 in every entry when an intercept is
;; fitted (ICPT 1), destroyed.  Q gets its eigenvectors as columns, MU
;; the eigenvalues (negative ones set to zero), R = Q' YC.  Returns the
;; column of Q nearest the constant vector with an intercept (the
;; largest |Q' 1|, scikit-learn's _find_smallest_angle), else -1.
(define (ridge-gcv-dual k q mu yc r n t icpt)
  (let ((e (make-vector n 0.0)))
    (sym-eigen k q mu e n)
    (do ((c 0 (+ c 1))) ((= c n))
      (if (< (vector-ref mu c) 0.0) (vector-set! mu c 0.0) 0))
    (with-arrays ((q (n n)) (yc (n t)) (r (n t)))
      (array-set! r (matmul (transpose q) yc)))
    (if (= icpt 1)
        (let ((best 0) (top -1.0))
          (do ((c 0 (+ c 1))) ((= c n))
            (let ((acc 0.0))
              (do ((i 0 (+ i 1))) ((= i n))
                (set! acc (+ acc (vector-ref q (+ (* i n) c)))))
              (if (> (abs acc) top)
                  (begin (set! top (abs acc)) (set! best c))
                  0)))
          best)
        -1)))

;; The dual's scan: Q (n x n), MU and R from ridge-gcv-dual, DROP its
;; return value; MSE, LOO and STORE as ridge-gcv-scan's.
(define (ridge-gcv-scan-dual q mu r alphas drop mse loo store n t na)
  (let ((q2 (make-vector (* n n) 0.0))
        (w (make-vector (* n na) 0.0))
        (rw (make-vector (* n na) 0.0))
        (gd (make-vector (* n na) 0.0))
        (c (make-vector (* n na) 0.0)))
    (do ((s 0 (+ s 1))) ((= s (* n n)))
      (vector-set! q2 s (* (vector-ref q s) (vector-ref q s))))
    (do ((k 0 (+ k 1))) ((= k n))
      (do ((a 0 (+ a 1))) ((= a na))
        (vector-set! w (+ (* k na) a)
                     (if (= k drop) 0.0 (/ 1.0 (+ (vector-ref mu k) (vector-ref alphas a)))))))
    (with-arrays ((q2 (n n)) (w (n na)) (gd (n na)))
      (array-set! gd (matmul q2 w)))
    (do ((j 0 (+ j 1))) ((= j t))
      (do ((k 0 (+ k 1))) ((= k n))
        (do ((a 0 (+ a 1))) ((= a na))
          (vector-set! rw (+ (* k na) a) (* (vector-ref r (+ (* k t) j)) (vector-ref w (+ (* k na) a))))))
      (with-arrays ((q (n n)) (rw (n na)) (c (n na)))
        (array-set! c (matmul q rw)))
      (do ((a 0 (+ a 1))) ((= a na)) (vector-set! mse (+ (* a t) j) 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (do ((a 0 (+ a 1))) ((= a na))
          (let ((e (/ (vector-ref c (+ (* i na) a)) (vector-ref gd (+ (* i na) a)))))
            (vector-set! mse (+ (* a t) j)
                         (+ (vector-ref mse (+ (* a t) j)) (/ (* e e) (exact->inexact n))))
            (if (= store 1) (vector-set! loo (+ (* (+ (* i t) j) na) a) (* e e)) 0)))))
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

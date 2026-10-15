;;;; PCA by the covariance's eigenvectors, whole: scikit-learn's
;;;; PCA(svd_solver="covariance_eigh"), the solver its "auto" takes for a
;;;; tall design (p <= 1000, n >= 10 p), written out in the subset.
;;;;
;;;; C = X'X (a product) less n mu mu', over n - 1; its eigenvalues and
;;;; eigenvectors by sym-eigen.scm, in decreasing order, negative
;;;; eigenvalues set to zero; the singular values sqrt(ev (n - 1)); each
;;;; component (an eigenvector) signed so that its entry of largest
;;;; magnitude is positive (svd_flip with u_based_decision=False).
;;;;
;;;; X is n rows of p.  COMPS (p x p) gets the components as rows, EV the
;;;; explained variances, SV the singular values, MEAN the mean.
;;;;
;;;;[ja] 共分散の固有ベクトルによる PCA 全体: scikit-learn の
;;;;[ja] PCA(svd_solver="covariance_eigh")(縦長の設計行列で "auto" が選ぶ解法)
;;;;[ja] をそのままサブセットで書いたもの。C = X'X(行列積)- n mu mu' を
;;;;[ja] n - 1 で割り、三重対角化と QL 法で固有分解、降順、負の固有値は 0、svd_flip の符号。

(include "sym-eigen.scm")

(define (pca x comps ev sv mean n p)
  (let ((c (make-vector (* p p) 0.0))
        (v (make-vector (* p p) 0.0))
        (e (make-vector p 0.0))
        (sc (make-vector p 0.0))
        (ord (make-vector p 0)))
    ;; the mean, row by row
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! mean j 0.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! mean j (+ (vector-ref mean j) (vector-ref x (+ (* i p) j))))))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! mean j (/ (vector-ref mean j) (exact->inexact n))))
    (with-arrays ((x (n p)) (c (p p)))
      (array-set! c (matmul (transpose x) x)))
    (do ((i 0 (+ i 1))) ((= i p))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! c (+ (* i p) j)
                     (/ (- (vector-ref c (+ (* i p) j))
                           (* (exact->inexact n) (* (vector-ref mean i) (vector-ref mean j))))
                        (exact->inexact (- n 1))))))
    (sym-eigen c v e sc p)
    (eig-order e ord p)
    (do ((r 0 (+ r 1))) ((= r p))
      (let ((col (vector-ref ord r)))
        (let ((lam (if (< (vector-ref e col) 0.0) 0.0 (vector-ref e col)))
              (big 0) (bv -1.0))
          (vector-set! ev r lam)
          (vector-set! sv r (sqrt (* lam (exact->inexact (- n 1)))))
          (do ((j 0 (+ j 1))) ((= j p))
            (let ((a (vector-ref v (+ (* j p) col))))
              (let ((aa (if (< a 0.0) (- 0.0 a) a)))
                (if (> aa bv) (begin (set! bv aa) (set! big j)) 0))))
          (let ((sg (if (< (vector-ref v (+ (* big p) col)) 0.0) -1.0 1.0)))
            (do ((j 0 (+ j 1))) ((= j p))
              (vector-set! comps (+ (* r p) j) (* sg (vector-ref v (+ (* j p) col)))))))))
    0))

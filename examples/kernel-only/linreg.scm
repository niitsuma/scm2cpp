;;;; Ordinary least squares over the Gram matrix: scikit-learn's
;;;; LinearRegression takes LAPACK's gelsd on the n x p design; here the
;;;; rows are read once, into G = Xc'Xc and B = Xc'y (dsyrk and dgemm
;;;; under --blas), and the rest is p x p.
;;;;
;;;; The normal equations square the condition number, so the solve is
;;;; guarded: with D = diag(sqrt G_jj), S = D^-1 G D^-1 is solved by
;;;; Cholesky with the reciprocal of its condition number (spd-solve-
;;;; rcond: dposv and dpocon under --blas), and the answer
;;;; b = D^-1 S^-1 D^-1 B is taken only when that is at least RATIO
;;;; (relative error about eps / RATIO; the column scaling takes the
;;;; units out of the condition) and when G itself, whose condition is
;;;; at most (max d / min d)^2 times S's, has no singular value below
;;;; TOL times the largest (LAPACK gelsd's rank cut, which scikit-learn
;;;; sets to its tol).  Otherwise -- a rank-deficient or badly
;;;; conditioned design -- the caller falls back to least squares on X.
;;;;
;;;;[ja] 最小二乗を Gram で: 行は 1 回だけ読んで G = Xc'Xc と B = Xc'y にし、あとは
;;;;[ja] p x p。正規方程式は条件数を 2 乗にするので、列を尺度でそろえた
;;;;[ja] S = D^-1 G D^-1 を Cholesky で解いて条件数の逆数も出し(--blas で dposv と
;;;;[ja] dpocon)、それが RATIO 以上で、G の特異値が TOL 倍未満に落ちないときだけ答えを
;;;;[ja] 使う。そうでなければ呼び出し側が X の上の最小二乗に回す。

(include "sym-eigen.scm")
(include "gram.scm")

;; G (p x p) and B (p x t) destroyed; COEF (p x t) gets the solution.
;; Returns 1 when it was taken, 0 when the guard refused it (COEF then
;; untouched).
(define (linreg-solve g b coef p t ratio tol)
  (let ((d (make-vector p 0.0)) (dmax 0.0) (dmin 1e300) (zero 0))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((gjj (vector-ref g (+ (* j p) j))))
        (if (> gjj 0.0)
            (begin
              (vector-set! d j (sqrt gjj))
              (if (> gjj dmax) (set! dmax gjj) 0)
              (if (< gjj dmin) (set! dmin gjj) 0))
            (set! zero 1))))
    (if (= zero 1)
        0
        (begin
          (do ((a 0 (+ a 1))) ((= a p))
            (do ((c 0 (+ c 1))) ((= c p))
              (vector-set! g (+ (* a p) c)
                           (/ (vector-ref g (+ (* a p) c)) (* (vector-ref d a) (vector-ref d c))))))
          (do ((j 0 (+ j 1))) ((= j p))
            (do ((q 0 (+ q 1))) ((= q t))
              (vector-set! b (+ (* j t) q) (/ (vector-ref b (+ (* j t) q)) (vector-ref d j)))))
          (let ((rc (spd-solve-rcond g b p t)))
            ;; dmax, dmin are squares already: G's condition <= (dmax/dmin) / rc
            (if (and (>= rc ratio) (<= (/ dmax dmin) (* rc (/ 1.0 (* (* 1.0 tol) tol)))))
                (begin
                  (do ((j 0 (+ j 1))) ((= j p))
                    (do ((q 0 (+ q 1))) ((= q t))
                      (vector-set! coef (+ (* j t) q) (/ (vector-ref b (+ (* j t) q)) (vector-ref d j)))))
                  1)
                0))))))

;; S (p) gets the singular values of the design behind G (p x p,
;; destroyed): the square roots of G's eigenvalues, largest first,
;; negative rounding taken as zero.  Returns how many exceed TOL times
;; the largest (LAPACK gelsd's rank at rcond TOL).
(define (linreg-singular g s p tol)
  (let ((v (make-vector (* p p) 0.0))
        (lam (make-vector p 0.0))
        (e (make-vector p 0.0))
        (ord (make-vector p 0))
        (rank 0))
    (sym-eigen g v lam e p)
    (eig-order lam ord p)
    (do ((r 0 (+ r 1))) ((= r p))
      (let ((x (vector-ref lam (vector-ref ord r))))
        (vector-set! s r (if (> x 0.0) (sqrt x) 0.0))))
    (do ((r 0 (+ r 1))) ((= r p))
      (if (> (vector-ref s r) (* tol (vector-ref s 0))) (set! rank (+ rank 1)) 0))
    rank))

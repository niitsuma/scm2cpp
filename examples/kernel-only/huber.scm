;;;; The Huber regressor, whole: scikit-learn's HuberRegressor, its
;;;; _huber_loss_and_gradient and the L-BFGS-B run of lbfgs.scm with the
;;;; scale bounded below by 10 eps, written out in the subset.
;;;;
;;;; The parameters are the weights w (p), the intercept b and the scale
;;;; sigma, in that order (scikit-learn's), starting at zero with sigma 1.
;;;; With r = y - X w - b, a point is an outlier when |r| > EPSILON sigma;
;;;; the objective is
;;;;   n sigma + sum_inliers r^2 / sigma
;;;;     + sum_outliers (2 EPSILON |r| - sigma EPSILON^2) + ALPHA |w|^2,
;;;; its gradient scikit-learn's.  X w and the gradient X'c are products
;;;; (--blas: dgemv).  scipy's defaults otherwise: ftol 2.2e-9, 20 line
;;;; search evaluations.
;;;;
;;;; X is n rows of p.  COEF (p + 2) is the start (zeros, sigma 1) and the
;;;; result: the weights, the intercept, the scale.  FITINT 0 keeps b at
;;;; zero.  OUT[0] gets the objective, OUT[1] the evaluations.  Returns
;;;; n_iter_.
;;;;
;;;;[ja] Huber 回帰全体: scikit-learn の HuberRegressor と
;;;;[ja] _huber_loss_and_gradient を、スケールに下限 10 eps を付けた
;;;;[ja] L-BFGS-B(lbfgs.scm)でそのままサブセットで書いたもの。変数は重み、
;;;;[ja] 切片、スケールの順。X w と勾配 X'c は行列積(--blas で dgemv)。

;; f at COEF, the gradient into G; Z (n) is scratch
(define (huber-fg coef g x y z epsilon alpha fitint n p)
  (let ((b (vector-ref coef p)) (sigma (vector-ref coef (+ p 1)))
        (nout 0) (outsum 0.0) (sq 0.0) (csum 0.0) (ww 0.0))
    (with-arrays ((x (n p)) (coef (p)) (z (n)))
      (array-set! z (matmul x coef)))
    ;; the residuals; Z becomes the gradient's row weights c
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((r (- (- (vector-ref y i) (vector-ref z i)) b)))
        (let ((a (lb-abs r)))
          (if (> a (* epsilon sigma))
              (begin
                (set! nout (+ nout 1))
                (set! outsum (+ outsum a))
                (vector-set! z i (* -2.0 (* epsilon (if (< r 0.0) -1.0 1.0)))))
              (begin
                (set! sq (+ sq (* r r)))
                (vector-set! z i (/ (* -2.0 r) sigma))))
          (set! csum (+ csum (vector-ref z i))))))
    (with-arrays ((x (n p)) (g (p)) (z (n)))
      (array-set! g (matmul (transpose x) z)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((wj (vector-ref coef j)))
        (set! ww (+ ww (* wj wj)))
        (vector-set! g j (+ (vector-ref g j) (* 2.0 (* alpha wj))))))
    (vector-set! g p (if (= fitint 1) csum 0.0))
    (let ((sqloss (/ sq sigma)) (eps2 (* epsilon epsilon)))
      (vector-set! g (+ p 1) (- (- (exact->inexact n) (* (exact->inexact nout) eps2)) (/ sqloss sigma)))
      (+ (+ (+ (* (exact->inexact n) sigma) sqloss)
            (- (* 2.0 (* epsilon outsum)) (* sigma (* (exact->inexact nout) eps2))))
         (* alpha ww)))))

(define (huber x y coef out epsilon alpha maxiter tol fitint n p)
  (let ((aux (make-vector 3 0.0))
        (work (make-vector n 0.0)))
    (vector-set! aux 0 epsilon)
    (vector-set! aux 1 alpha)
    (vector-set! aux 2 (if (= fitint 1) 1.0 0.0))
    (lbfgs 1 coef x y aux work out 10 maxiter tol (* 1e7 2.220446049250313e-16) 20
           (+ p 1) (* 10.0 2.220446049250313e-16) (+ p 2) n p 1)))

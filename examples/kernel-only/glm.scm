;;;; Generalized linear models, whole: scikit-learn's PoissonRegressor,
;;;; GammaRegressor and TweedieRegressor (solver="lbfgs") -- the objective
;;;; of their LinearModelLoss and the L-BFGS-B run of lbfgs.scm.
;;;;
;;;; The objective is the mean half deviance plus ALPHA |w|^2 / 2, the
;;;; intercept not penalised.  FAMILY 0 is the half Poisson loss
;;;; e^z - y z, 1 the half Gamma loss z + y e^-z, 2 the half Tweedie loss
;;;; of POWER with the log link (e^((2-p)z)/(2-p) - y e^((1-p)z)/(1-p), the
;;;; powers 0, 1 and 2 by their own branches, as scikit-learn has them),
;;;; 3 the half squared error with the identity link (Tweedie power 0,
;;;; TweedieRegressor's default).  z = X w + b; X w and the gradient X'r are
;;;; products (--blas: dgemv).  The start is scikit-learn's: w = 0, b the
;;;; link of the mean of y.
;;;;
;;;; X is n rows of p.  COEF (p + 1) gets the weights then the intercept;
;;;; OUT[0] the objective, OUT[1] the evaluations.  Returns n_iter_.
;;;;
;;;;[ja] 一般化線形モデル全体: scikit-learn の PoissonRegressor、GammaRegressor、
;;;;[ja] TweedieRegressor(solver="lbfgs")の目的関数と lbfgs.scm の L-BFGS-B。
;;;;[ja] 損失の平均 + ALPHA |w|^2 / 2(切片は正則化しない)。FAMILY 0 Poisson、
;;;;[ja] 1 Gamma、2 Tweedie(log リンク、POWER)、3 恒等リンクの二乗誤差
;;;;[ja] (Tweedie の power 0)。初期値は w = 0、b = link(mean y)。

;; f at COEF, the gradient into G; Z (n) is scratch
(define (glm-fg coef g x y z family power l2 fitint n p)
  (let ((loss 0.0) (pen 0.0) (b (vector-ref coef p)))
    (with-arrays ((x (n p)) (coef (p)) (z (n)))
      (array-set! z (matmul x coef)))
    ;; the pointwise loss, and its gradient over z in place
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((zi (+ (vector-ref z i) b)) (yi (vector-ref y i)))
        (if (or (= family 0) (and (= family 2) (= power 1.0)))
            (let ((e (exp zi)))
              (set! loss (+ loss (- e (* yi zi))))
              (vector-set! z i (- e yi)))
            (if (or (= family 1) (and (= family 2) (= power 2.0)))
                (let ((e2 (exp (- 0.0 zi))))
                  (set! loss (+ loss (+ zi (* yi e2))))
                  (vector-set! z i (- 1.0 (* yi e2))))
                (if (= family 3)
                    (let ((r (- zi yi)))
                      (set! loss (+ loss (* 0.5 (* r r))))
                      (vector-set! z i r))
                    (if (= power 0.0)
                        (let ((e3 (exp zi)))
                          (set! loss (+ loss (* 0.5 (* (- e3 yi) (- e3 yi)))))
                          (vector-set! z i (* e3 (- e3 yi))))
                        (let ((e1 (exp (* (- 1.0 power) zi)))
                              (e4 (exp (* (- 2.0 power) zi))))
                          (set! loss (+ loss (- (/ e4 (- 2.0 power)) (/ (* yi e1) (- 1.0 power)))))
                          (vector-set! z i (- e4 (* yi e1))))))))))
    (with-arrays ((x (n p)) (g (p)) (z (n)))
      (array-set! g (matmul (transpose x) z)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((wj (vector-ref coef j)))
        (set! pen (+ pen (* wj wj)))
        (vector-set! g j (+ (/ (vector-ref g j) (exact->inexact n)) (* l2 wj)))))
    (let ((acc 0.0))
      (if (= fitint 1)
          (do ((i 0 (+ i 1))) ((= i n)) (set! acc (+ acc (vector-ref z i))))
          0)
      (vector-set! g p (/ acc (exact->inexact n))))
    (+ (/ loss (exact->inexact n)) (* 0.5 (* l2 pen)))))

(define (glm x y coef out family power alpha maxiter tol fitint n p)
  (let ((aux (make-vector 4 0.0))
        (work (make-vector n 0.0))
        (ym 0.0))
    (vector-set! aux 0 alpha)
    (vector-set! aux 1 (exact->inexact family))
    (vector-set! aux 2 (if (= fitint 1) 1.0 0.0))
    (vector-set! aux 3 power)
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! coef j 0.0))
    (do ((i 0 (+ i 1))) ((= i n)) (set! ym (+ ym (vector-ref y i))))
    (set! ym (/ ym (exact->inexact n)))
    (vector-set! coef p (if (= fitint 1) (if (= family 3) ym (log ym)) 0.0))
    (lbfgs 2 coef x y aux work out 10 maxiter tol (* 64.0 2.220446049250313e-16) 50 -1 0.0
           (+ p 1) n p 1)))

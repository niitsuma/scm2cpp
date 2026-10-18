;;;; L2-penalised logistic regression, whole: scikit-learn's
;;;; LogisticRegression(solver="lbfgs"), written out in the subset --
;;;; the objective of its LinearModelLoss and the L-BFGS-B run of
;;;; lbfgs.scm.
;;;;
;;;; The objective is scikit-learn's: the mean pointwise loss plus
;;;; l2 |W|^2 / 2, l2 = 1 / (C n), the intercepts not penalised.  Two
;;;; classes (MULTI 0, K 1) use the half binomial loss, log(1 + e^z) - y z
;;;; with y in {0, 1}, its gradient e^z / (1 + e^z) - y (scikit-learn's
;;;; branches at z = -37, -2, 18, one exponential each; log1p is
;;;; log(1 + .) here); more (MULTI 1, K classes) the half multinomial
;;;; loss, logsumexp(z) - z_y, its gradient softmax(z) - onehot(y), y the
;;;; class index.  The raw predictions Z = X W' + b and the gradient
;;;; R' X are products (--blas: dgemm).
;;;;
;;;; X is n rows of p; COEF is K rows of p then the K intercepts, zero on
;;;; entry (scikit-learn's start), the result on return.  OUT[0] gets the
;;;; objective, OUT[1] the number of evaluations.  Returns n_iter_.
;;;;

;; f at COEF, the gradient into G; Z (n x k) is scratch
(define (logistic-fg coef g x y z l2 multi fitint n p k)
  (let ((loss 0.0) (pen 0.0))
    (with-arrays ((x (n p)) (coef (k p)) (z (n k)))
      (array-set! z (matmul x (transpose coef))))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((c 0 (+ c 1))) ((= c k))
        (vector-set! z (+ (* i k) c) (+ (vector-ref z (+ (* i k) c)) (vector-ref coef (+ (* k p) c))))))
    ;; the pointwise loss, and its gradient over Z in place
    (if (= multi 0)
        (do ((i 0 (+ i 1))) ((= i n))
          ;; scikit-learn's closs_grad_half_binomial: one exponential
          (let ((zi (vector-ref z i)) (yi (vector-ref y i)))
            (if (<= zi -2.0)
                (let ((e1 (exp zi)))
                  (if (<= zi -37.0)
                      (begin
                        (set! loss (+ loss (- e1 (* yi zi))))
                        (vector-set! z i (- e1 yi)))
                      (begin
                        (set! loss (+ loss (- (log (+ 1.0 e1)) (* yi zi))))
                        (vector-set! z i (/ (- (* (- 1.0 yi) e1) yi) (+ 1.0 e1))))))
                (let ((e2 (exp (- 0.0 zi))))
                  (set! loss (+ loss (+ (if (<= zi 18.0) (log (+ 1.0 e2)) e2) (* (- 1.0 yi) zi))))
                  (vector-set! z i (/ (- (- 1.0 yi) (* yi e2)) (+ 1.0 e2)))))))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((zmax (vector-ref z (* i k))) (se 0.0) (yc (vector-ref y i)))
            (do ((c 1 (+ c 1))) ((= c k))
              (if (> (vector-ref z (+ (* i k) c)) zmax) (set! zmax (vector-ref z (+ (* i k) c))) 0))
            ;; the loss at the true class, then the exponentials in place
            (set! loss (- loss (vector-ref z (+ (* i k) (inexact->exact yc)))))
            (do ((c 0 (+ c 1))) ((= c k))
              (let ((ec (exp (- (vector-ref z (+ (* i k) c)) zmax))))
                (vector-set! z (+ (* i k) c) ec)
                (set! se (+ se ec))))
            (set! loss (+ loss (+ zmax (log se))))
            (do ((c 0 (+ c 1))) ((= c k))
              (vector-set! z (+ (* i k) c) (/ (vector-ref z (+ (* i k) c)) se)))
            (let ((iy (+ (* i k) (inexact->exact yc))))
              (vector-set! z iy (- (vector-ref z iy) 1.0))))))
    ;; the gradient: R' X / n + l2 W, and the intercepts' column sums
    (with-arrays ((x (n p)) (g (k p)) (z (n k)))
      (array-set! g (matmul (transpose z) x)))
    (do ((t 0 (+ t 1))) ((= t (* k p)))
      (let ((wt (vector-ref coef t)))
        (set! pen (+ pen (* wt wt)))
        (vector-set! g t (+ (/ (vector-ref g t) (exact->inexact n)) (* l2 wt)))))
    (do ((c 0 (+ c 1))) ((= c k))
      (let ((acc 0.0))
        (if (= fitint 1)
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc (vector-ref z (+ (* i k) c)))))
            0)
        (vector-set! g (+ (* k p) c) (/ acc (exact->inexact n)))))
    (+ (/ loss (exact->inexact n)) (* 0.5 (* l2 pen)))))

(define (logistic-lbfgs x y coef out c maxiter tol multi fitint n p k)
  (let ((aux (make-vector 4 0.0))
        (work (make-vector (* n k) 0.0)))
    (vector-set! aux 0 (/ 1.0 (* c (exact->inexact n))))
    (vector-set! aux 1 (if (= multi 1) 1.0 0.0))
    (vector-set! aux 2 (if (= fitint 1) 1.0 0.0))
    (lbfgs 0 coef x y aux work out 10 maxiter tol (* 64.0 2.220446049250313e-16) 50 -1 0.0
           (* k (+ p 1)) n p k)))

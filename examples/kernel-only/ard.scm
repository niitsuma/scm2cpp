;;;; Automatic relevance determination, whole: scikit-learn's
;;;; ARDRegression.fit for n >= p (its _update_sigma), written out in the
;;;; subset.
;;;;
;;;; alpha starts at 1 / (var y + eps), every lambda at 1, every feature
;;;; kept.  Each iteration: sigma = pinvh(diag(lambda_k) + alpha G_kk) over
;;;; the kept features k (scipy's pinvh: the eigenvectors by sym-eigen.scm,
;;;; eigenvalues at most k eps max|ev| dropped); coef_k = alpha sigma
;;;; (X'y)_k; sse = |y - X coef|^2 (a product); gamma = 1 - lambda_k
;;;; diag(sigma); lambda_k = (gamma + 2 LAMBDA1) / (coef_k^2 + 2 LAMBDA2);
;;;; alpha = (n - sum gamma + 2 ALPHA1) / (sse + 2 ALPHA2); a feature whose
;;;; lambda reaches THRESH is dropped and its coefficient zeroed.  The fit
;;;; stops when the coefficients move by less than TOL in sum (after the
;;;; first iteration), when no feature is left, or after MAXITER; sigma and
;;;; coef are then computed once more from the final alpha and lambda.
;;;;
;;;; G_kk is the kept features' Gram.  scikit-learn forms it from X every
;;;; iteration (HOIST 0 does the same: the kept columns gathered, then a
;;;; product); HOIST 1 takes it from X'X formed once, the same numbers to
;;;; rounding -- the loop-invariant product moved out of the loop, by
;;;; hand; --derive (rewrite-invariant.scm) derives the same from HOIST 0,
;;;; which is why the Gram is formed in ard's loop rather than in
;;;; ard-sigma-coef.  X'y is formed once either way.
;;;;
;;;; X is n rows of p, centred by the caller when an intercept is fitted.
;;;; COEF and LAM (p) get the coefficients and the lambdas; SIGMA (p x p)
;;;; gets the final k x k sigma in its first k^2 entries; OUT[0] alpha,
;;;; OUT[1] k.  Returns n_iter_.
;;;;

(include "sym-eigen.scm")

;; S = pinvh(A) for the K x K matrix A (destroyed); V, EV, E scratch
(define (ard-pinvh a s v ev e k)
  (sym-eigen a v ev e k)
  (let ((mx 0.0))
    (do ((r 0 (+ r 1))) ((= r k))
      (let ((av (if (< (vector-ref ev r) 0.0) (- 0.0 (vector-ref ev r)) (vector-ref ev r))))
        (if (> av mx) (set! mx av) 0)))
    (let ((cut (* mx (* (exact->inexact k) 2.220446049250313e-16))))
      (do ((i 0 (+ i 1))) ((= i k))
        (do ((j 0 (+ j 1))) ((= j k))
          (let ((acc 0.0))
            (do ((r 0 (+ r 1))) ((= r k))
              (let ((er (vector-ref ev r)))
                (if (> (if (< er 0.0) (- 0.0 er) er) cut)
                    (set! acc (+ acc (/ (* (vector-ref v (+ (* i k) r)) (vector-ref v (+ (* j k) r))) er)))
                    0)))
            (vector-set! s (+ (* i k) j) acc))))))
  0)

;; sigma and coef from alpha and lambda over the kept features IDX (K of
;; them), GK their Gram: A = diag(lambda) + alpha G_kk, sigma = pinvh(A),
;; coef_k = alpha sigma (X'y)_k
(define (ard-sigma-coef xy idx lam coef sigma a v ev e gk alpha k)
  (do ((r 0 (+ r 1))) ((= r k))
    (do ((c 0 (+ c 1))) ((= c k))
      (vector-set! a (+ (* r k) c)
                   (+ (if (= r c) (vector-ref lam (vector-ref idx r)) 0.0)
                      (* alpha (vector-ref gk (+ (* r k) c)))))))
  (ard-pinvh a sigma v ev e k)
  (do ((r 0 (+ r 1))) ((= r k))
    (let ((acc 0.0))
      (do ((c 0 (+ c 1))) ((= c k))
        (set! acc (+ acc (* (vector-ref sigma (+ (* r k) c)) (vector-ref xy (vector-ref idx c))))))
      (vector-set! coef (vector-ref idx r) (* alpha acc))))
  0)

(define (ard x y coef sigma lam out maxiter tol alpha1 alpha2 lambda1 lambda2 thresh hoist n p)
  (let ((g (make-vector (if (= hoist 1) (* p p) 1) 0.0))
        (xy (make-vector p 0.0))
        (xk (make-vector (if (= hoist 1) 1 (* n p)) 0.0))
        (gk (make-vector (* p p) 0.0))
        (a (make-vector (* p p) 0.0))
        (v (make-vector (* p p) 0.0))
        (ev (make-vector p 0.0))
        (e (make-vector p 0.0))
        (r (make-vector n 0.0))
        (idx (make-vector p 0))
        (keep (make-vector p 1))
        (old (make-vector p 0.0))
        (alpha 0.0) (k p) (it 0) (done 0))
    (if (= hoist 1)
        (with-arrays ((x (n p)) (g (p p)))
          (array-set! g (matmul (transpose x) x)))
        0)
    (with-arrays ((x (n p)) (y (n)) (xy (p)))
      (array-set! xy (matmul (transpose x) y)))
    ;; alpha = 1 / (var y + eps)
    (let ((ym 0.0) (vy 0.0))
      (do ((i 0 (+ i 1))) ((= i n)) (set! ym (+ ym (vector-ref y i))))
      (set! ym (/ ym (exact->inexact n)))
      (do ((i 0 (+ i 1))) ((= i n))
        (set! vy (+ vy (* (- (vector-ref y i) ym) (- (vector-ref y i) ym)))))
      (set! alpha (/ 1.0 (+ (/ vy (exact->inexact n)) 2.220446049250313e-16))))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! lam j 1.0)
      (vector-set! coef j 0.0))
    (do () ((or (= done 1) (>= it maxiter)))
      (set! k 0)
      (do ((j 0 (+ j 1))) ((= j p))
        (if (= (vector-ref keep j) 1) (begin (vector-set! idx k j) (set! k (+ k 1))) 0))
      ;; the kept features' Gram: gathered from X'X, or formed from X
      (if (= hoist 1)
          (do ((r 0 (+ r 1))) ((= r k))
            (do ((c 0 (+ c 1))) ((= c k))
              (vector-set! gk (+ (* r k) c) (vector-ref g (+ (* (vector-ref idx r) p) (vector-ref idx c))))))
          (begin
            (do ((i 0 (+ i 1))) ((= i n))
              (do ((c 0 (+ c 1))) ((= c k))
                (vector-set! xk (+ (* i k) c) (vector-ref x (+ (* i p) (vector-ref idx c))))))
            (with-arrays ((xk (n k)) (gk (k k)))
              (array-set! gk (matmul (transpose xk) xk)))))
      (ard-sigma-coef xy idx lam coef sigma a v ev e gk alpha k)
      ;; sse = |y - X coef|^2
      (with-arrays ((x (n p)) (coef (p)) (r (n)))
        (array-set! r (matmul x coef)))
      (let ((sse 0.0) (gsum 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((d (- (vector-ref y i) (vector-ref r i))))
            (set! sse (+ sse (* d d)))))
        (do ((c 0 (+ c 1))) ((= c k))
          (let ((j (vector-ref idx c)))
            (let ((gm (- 1.0 (* (vector-ref lam j) (vector-ref sigma (+ (* c k) c))))))
              (set! gsum (+ gsum gm))
              (vector-set! lam j (/ (+ gm (* 2.0 lambda1))
                                    (+ (* (vector-ref coef j) (vector-ref coef j)) (* 2.0 lambda2)))))))
        (set! alpha (/ (+ (- (exact->inexact n) gsum) (* 2.0 alpha1)) (+ sse (* 2.0 alpha2)))))
      (let ((nk 0) (moved 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (if (< (vector-ref lam j) thresh)
              (begin (vector-set! keep j 1) (set! nk (+ nk 1)))
              (begin (vector-set! keep j 0) (vector-set! coef j 0.0)))
          (let ((dv (- (vector-ref old j) (vector-ref coef j))))
            (set! moved (+ moved (if (< dv 0.0) (- 0.0 dv) dv)))))
        (if (and (> it 0) (< moved tol))
            (set! done 1)
            (begin
              (do ((j 0 (+ j 1))) ((= j p)) (vector-set! old j (vector-ref coef j)))
              (if (= nk 0) (set! done 1) 0))))
      (set! it (+ it 1)))
    ;; sigma and coef once more from the final alpha and lambda
    (set! k 0)
    (do ((j 0 (+ j 1))) ((= j p))
      (if (= (vector-ref keep j) 1) (begin (vector-set! idx k j) (set! k (+ k 1))) 0))
    (if (> k 0)
        (begin
          (if (= hoist 1)
              (do ((r 0 (+ r 1))) ((= r k))
                (do ((c 0 (+ c 1))) ((= c k))
                  (vector-set! gk (+ (* r k) c) (vector-ref g (+ (* (vector-ref idx r) p) (vector-ref idx c))))))
              (begin
                (do ((i 0 (+ i 1))) ((= i n))
                  (do ((c 0 (+ c 1))) ((= c k))
                    (vector-set! xk (+ (* i k) c) (vector-ref x (+ (* i p) (vector-ref idx c))))))
                (with-arrays ((xk (n k)) (gk (k k)))
                  (array-set! gk (matmul (transpose xk) xk)))))
          (ard-sigma-coef xy idx lam coef sigma a v ev e gk alpha k))
        0)
    (vector-set! out 0 alpha)
    (vector-set! out 1 (exact->inexact k))
    it))

;;;; Quantile regression by the Frisch-Newton interior point method
;;;; (Portnoy and Koenker 1997, the predictor-corrector of Koenker's
;;;; rq.fit.fnb / lp_fnm), where scikit-learn's QuantileRegressor by
;;;; default hands the linear program to a simplex code.
;;;;
;;;; The problem is  min_b  sum_i rho_i(yy_i - A_i b),  rho_i(r) =
;;;; r (tau_i - [r < 0]), over the n rows of A (m columns: the caller
;;;; has put the intercept's column and, for an L1 penalty, one row per
;;;; penalised coefficient into A).  Its dual is
;;;;   min c'x   subject to   A'x = A'x0,  0 <= x <= 1,
;;;; with c = -yy and x0_i = 1 - tau_i, and the coefficients are minus
;;;; the multipliers y of the equality.  With slacks s = 1 - x and the
;;;; dual slacks z, w (A y + z - w = c), each iteration solves
;;;;   A' Q A dy = A' Q (z - w),   Q = diag(1 / (z/x + w/s)),
;;;; once for the affine step and, when that step is cut short by a
;;;; bound, once more for Mehrotra's corrected one: a weighted Gram
;;;; matrix (dsyrk under --blas, of the rows scaled by sqrt q) and a
;;;; Cholesky solve (dposv).  Some 15 to 45 iterations, whatever n is.
;;;;
;;;; It stops when the duality gap c'x - b'y + sum w falls to TOL times
;;;; the objective (or to 1e-14 sum |c|, what rounding leaves of it).
;;;; A Gram matrix that is not positive definite -- dependent columns,
;;;; or more columns than rows -- ends it: the caller then takes
;;;; another solver.
;;;;
;;;;
;;;; lu-solve is the square solve the caller then uses to move that
;;;; answer to its vertex (the fit through the rows whose x stayed
;;;; inside (0, 1)): Gaussian elimination with partial pivoting, on one
;;;; thread.

(include "gram.scm")

;; A x = B: A (n x n by rows) is overwritten by its factors, B by x.
;; Returns 0, or 1 when a pivot is zero (B is then not a solution).
(define (lu-solve a b n)
  (let ((bad 0))
    (do ((k 0 (+ k 1))) ((or (= bad 1) (>= k n)))
      (let ((piv k) (big (gram-abs (vector-ref a (+ (* k n) k)))))
        (do ((i (+ k 1) (+ i 1))) ((>= i n))
          (if (> (gram-abs (vector-ref a (+ (* i n) k))) big)
              (begin
                (set! big (gram-abs (vector-ref a (+ (* i n) k))))
                (set! piv i))
              0))
        (if (not (> big 0.0))
            (set! bad 1)
            (begin
              (if (not (= piv k))
                  (begin
                    (do ((j k (+ j 1))) ((>= j n))
                      (let ((t (vector-ref a (+ (* k n) j))))
                        (vector-set! a (+ (* k n) j) (vector-ref a (+ (* piv n) j)))
                        (vector-set! a (+ (* piv n) j) t)))
                    (let ((t (vector-ref b k)))
                      (vector-set! b k (vector-ref b piv))
                      (vector-set! b piv t)))
                  0)
              (do ((i (+ k 1) (+ i 1))) ((>= i n))
                (let ((l (/ (vector-ref a (+ (* i n) k)) (vector-ref a (+ (* k n) k)))))
                  (do ((j (+ k 1) (+ j 1))) ((>= j n))
                    (vector-set! a (+ (* i n) j)
                                 (- (vector-ref a (+ (* i n) j))
                                    (* l (vector-ref a (+ (* k n) j))))))
                  (vector-set! b i (- (vector-ref b i) (* l (vector-ref b k))))))))))
    (if (= bad 0)
        (do ((i (- n 1) (- i 1))) ((< i 0))
          (let ((s (vector-ref b i)))
            (do ((j (+ i 1) (+ j 1))) ((>= j n))
              (set! s (- s (* (vector-ref a (+ (* i n) j)) (vector-ref b j)))))
            (vector-set! b i (/ s (vector-ref a (+ (* i n) i))))))
        0)
    bad))

;; A (n x m) by rows.  C (n) = -yy.  X (n): the start x0 on entry
;; (strictly inside (0, 1)), the dual solution on return: strictly
;; inside (0, 1) only for the rows whose residual is zero.  COEF (m)
;; gets the coefficients.  OUT[0] the duality gap, OUT[1] the objective
;; it was measured against, OUT[2] the status: 0 converged, 1 MAXIT
;; reached, 2 a Gram matrix was not positive definite.  Returns the
;; iterations.
(define (quantile-fn a c x coef out tol maxit n m)
  (let ((s (make-vector n 0.0)) (z (make-vector n 0.0)) (w (make-vector n 0.0))
        (q (make-vector n 0.0)) (r (make-vector n 0.0)) (t (make-vector n 0.0))
        (dx (make-vector n 0.0)) (dz (make-vector n 0.0)) (dw (make-vector n 0.0))
        (aq (make-vector (* n m) 0.0))
        (g (make-vector (* m m) 0.0)) (g2 (make-vector (* m m) 0.0))
        (b (make-vector m 0.0)) (y (make-vector m 0.0))
        (dy (make-vector m 0.0)) (rhs (make-vector m 0.0)) (rhs2 (make-vector m 0.0))
        (beta 0.9995) (ca 0.0) (cnorm 0.0) (gap 0.0) (obj 0.0)
        (it 0) (status 0) (done 0))
    ;; b = A'x0; the least squares start A y = c
    (with-arrays ((a (n m)) (x (n)) (b (m)))
      (array-set! b (matmul (transpose a) x)))
    (do ((i 0 (+ i 1))) ((= i n))
      (set! ca (+ ca (* (vector-ref c i) (vector-ref x i))))
      (set! cnorm (+ cnorm (gram-abs (vector-ref c i))))
      (vector-set! s i (- 1.0 (vector-ref x i))))
    (with-arrays ((a (n m)) (g (m m)))
      (array-set! g (matmul (transpose a) a)))
    (with-arrays ((a (n m)) (c (n)) (y (m)))
      (array-set! y (matmul (transpose a) c)))
    (if (= (spd-solve g y m 1) 0)
        (begin
          (with-arrays ((a (n m)) (y (m)) (t (n)))
            (array-set! t (matmul a y)))
          (do ((i 0 (+ i 1))) ((= i n))
            (let ((ri (- (vector-ref c i) (vector-ref t i))))
              ;; a zero residual would start z and w both at zero
              (let ((rr (if (= ri 0.0) 0.001 ri)))
                (vector-set! z i (if (> rr 0.0) rr 0.0))
                (vector-set! w i (- (vector-ref z i) rr))))))
        (begin
          ;; what the failed solve left in y differs by backend
          (do ((j 0 (+ j 1))) ((= j m)) (vector-set! y j 0.0))
          (set! status 2)
          (set! done 1)))
    (do () ((or (= done 1) (>= it maxit)))
      (set! it (+ it 1))
      ;; the affine step
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((qi (/ 1.0 (+ (/ (vector-ref z i) (vector-ref x i))
                            (/ (vector-ref w i) (vector-ref s i))))))
          (let ((sq (sqrt qi)))
            (vector-set! q i qi)
            (vector-set! r i (- (vector-ref z i) (vector-ref w i)))
            (vector-set! t i (* qi (vector-ref r i)))
            (do ((j 0 (+ j 1))) ((= j m))
              (vector-set! aq (+ (* i m) j) (* sq (vector-ref a (+ (* i m) j))))))))
      (with-arrays ((aq (n m)) (g (m m)))
        (array-set! g (matmul (transpose aq) aq)))
      (with-arrays ((a (n m)) (t (n)) (rhs (m)))
        (array-set! rhs (matmul (transpose a) t)))
      (do ((k 0 (+ k 1))) ((= k (* m m))) (vector-set! g2 k (vector-ref g k)))
      (do ((j 0 (+ j 1))) ((= j m)) (vector-set! dy j (vector-ref rhs j)))
      (if (= (spd-solve g dy m 1) 0)
          (let ((fp 1e20) (fd 1e20))
            (with-arrays ((a (n m)) (dy (m)) (t (n)))
              (array-set! t (matmul a dy)))
            (do ((i 0 (+ i 1))) ((= i n))
              (let ((dxi (* (vector-ref q i) (- (vector-ref t i) (vector-ref r i)))))
                (let ((dzi (* (- 0.0 (vector-ref z i)) (+ 1.0 (/ dxi (vector-ref x i)))))
                      (dwi (* (- 0.0 (vector-ref w i)) (- 1.0 (/ dxi (vector-ref s i))))))
                  (vector-set! dx i dxi)
                  (vector-set! dz i dzi)
                  (vector-set! dw i dwi)
                  (if (< dxi 0.0) (set! fp (min fp (/ (- 0.0 (vector-ref x i)) dxi))) 0)
                  (if (> dxi 0.0) (set! fp (min fp (/ (vector-ref s i) dxi))) 0)
                  (if (< dzi 0.0) (set! fd (min fd (/ (- 0.0 (vector-ref z i)) dzi))) 0)
                  (if (< dwi 0.0) (set! fd (min fd (/ (- 0.0 (vector-ref w i)) dwi))) 0))))
            (set! fp (min (* beta fp) 1.0))
            (set! fd (min (* beta fd) 1.0))
            (if (< (min fp fd) 1.0)
                ;; a bound cut the step: the centring parameter from how far
                ;; the affine step would get, and the corrected step
                (let ((mu 0.0) (gg 0.0))
                  (do ((i 0 (+ i 1))) ((= i n))
                    (set! mu (+ mu (+ (* (vector-ref z i) (vector-ref x i))
                                      (* (vector-ref w i) (vector-ref s i)))))
                    (set! gg (+ gg (+ (* (+ (vector-ref z i) (* fd (vector-ref dz i)))
                                         (+ (vector-ref x i) (* fp (vector-ref dx i))))
                                      (* (+ (vector-ref w i) (* fd (vector-ref dw i)))
                                         (- (vector-ref s i) (* fp (vector-ref dx i))))))))
                  (let ((ratio (/ gg mu)))
                    (set! mu (/ (* mu (* ratio (* ratio ratio))) (* 2.0 (exact->inexact n)))))
                  (do ((i 0 (+ i 1))) ((= i n))
                    (let ((dxdz (* (vector-ref dx i) (vector-ref dz i)))
                          (dsdw (* (- 0.0 (vector-ref dx i)) (vector-ref dw i)))
                          (xi (* mu (- (/ 1.0 (vector-ref x i)) (/ 1.0 (vector-ref s i))))))
                      (vector-set! t i (* (vector-ref q i) (- (- dxdz dsdw) xi)))))
                  (with-arrays ((a (n m)) (t (n)) (rhs2 (m)))
                    (array-set! rhs2 (matmul (transpose a) t)))
                  (do ((j 0 (+ j 1))) ((= j m))
                    (vector-set! dy j (+ (vector-ref rhs j) (vector-ref rhs2 j))))
                  (if (= (spd-solve g2 dy m 1) 0)
                      (begin
                        (with-arrays ((a (n m)) (dy (m)) (t (n)))
                          (array-set! t (matmul a dy)))
                        (set! fp 1e20)
                        (set! fd 1e20)
                        (do ((i 0 (+ i 1))) ((= i n))
                          (let ((dxdz (* (vector-ref dx i) (vector-ref dz i)))
                                (dsdw (* (- 0.0 (vector-ref dx i)) (vector-ref dw i)))
                                (xinv (/ 1.0 (vector-ref x i)))
                                (sinv (/ 1.0 (vector-ref s i))))
                            (let ((dxi (* (vector-ref q i)
                                          (+ (- (- (+ (vector-ref t i) (* mu (- xinv sinv)))
                                                   (vector-ref r i))
                                                dxdz)
                                             dsdw))))
                              (let ((dzi (- (- (- (* mu xinv) (vector-ref z i))
                                               (* xinv (* (vector-ref z i) dxi)))
                                            dxdz))
                                    (dwi (- (+ (- (* mu sinv) (vector-ref w i))
                                               (* sinv (* (vector-ref w i) dxi)))
                                            dsdw)))
                                (vector-set! dx i dxi)
                                (vector-set! dz i dzi)
                                (vector-set! dw i dwi)
                                (if (< dxi 0.0) (set! fp (min fp (/ (- 0.0 (vector-ref x i)) dxi))) 0)
                                (if (> dxi 0.0) (set! fp (min fp (/ (vector-ref s i) dxi))) 0)
                                (if (< dzi 0.0) (set! fd (min fd (/ (- 0.0 (vector-ref z i)) dzi))) 0)
                                (if (< dwi 0.0) (set! fd (min fd (/ (- 0.0 (vector-ref w i)) dwi))) 0)))))
                        (set! fp (min (* beta fp) 1.0))
                        (set! fd (min (* beta fd) 1.0)))
                      (begin (set! status 2) (set! done 1))))
                0)
            (if (= status 0)
                (let ((cx 0.0) (sw 0.0) (yb 0.0))
                  (do ((i 0 (+ i 1))) ((= i n))
                    (vector-set! x i (+ (vector-ref x i) (* fp (vector-ref dx i))))
                    (vector-set! s i (- (vector-ref s i) (* fp (vector-ref dx i))))
                    (vector-set! z i (+ (vector-ref z i) (* fd (vector-ref dz i))))
                    (vector-set! w i (+ (vector-ref w i) (* fd (vector-ref dw i))))
                    (set! cx (+ cx (* (vector-ref c i) (vector-ref x i))))
                    (set! sw (+ sw (vector-ref w i))))
                  (do ((j 0 (+ j 1))) ((= j m))
                    (vector-set! y j (+ (vector-ref y j) (* fd (vector-ref dy j))))
                    (set! yb (+ yb (* (vector-ref y j) (vector-ref b j)))))
                  (set! gap (+ (- cx yb) sw))
                  ;; the dual value is -(objective) - c'x0
                  (set! obj (gram-abs (+ (- ca yb) sw)))
                  (if (<= gap (max (* tol obj) (* 1e-14 cnorm))) (set! done 1) 0))
                0))
          (begin (set! status 2) (set! done 1))))
    (if (and (= status 0) (= done 0)) (set! status 1) 0)
    (do ((j 0 (+ j 1))) ((= j m))
      (vector-set! coef j (- 0.0 (vector-ref y j))))
    (vector-set! out 0 gap)
    (vector-set! out 1 obj)
    (vector-set! out 2 (exact->inexact status))
    it))

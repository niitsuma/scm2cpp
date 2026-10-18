;;;; FastICA, whole: scikit-learn's FastICA at its defaults
;;;; (algorithm="parallel", fun="logcosh", whiten="unit-variance",
;;;; whiten_solver="svd") -- _fit_transform with _ica_par,
;;;; _sym_decorrelation and _logcosh -- written out in the subset.
;;;;
;;;; Whitening: X is centred; the left singular vectors u and values d of
;;;; X' (scikit-learn's svd) are the eigenvectors of the Gram X'X (a
;;;; product) and the square roots of its eigenvalues, by sym-eigen.scm,
;;;; in decreasing order, each u column signed by its first entry as
;;;; scikit-learn signs it; K = (u / d)' (the first NC rows) and X1 = K X'
;;;; sqrt(n) (a product).  The parallel iteration: W = sym(W_INIT); then
;;;; g = tanh(W X1) (a product), W1 = sym(g X1' / n - mean(1 - g^2) W) (a
;;;; product), stopping when max |abs(diag W1 W') - 1| < TOL or after
;;;; MAXITER, sym(W) = (W W')^(-1/2) W through the eigenvectors of W W'
;;;; (eigenvalues clipped at the smallest normal double).  Unit variance:
;;;; the sources' standard deviations divide the rows of W.
;;;;
;;;; X is n rows of p; WINIT the start (NC x NC, the caller's normal
;;;; draws, as scikit-learn's random_state.normal).  COMPS (NC x p) gets
;;;; W K, WHITE (NC x p) K, UNMIX (NC x NC) W, MEAN (p) the mean.  Returns
;;;; n_iter_.
;;;;

(include "sym-eigen.scm")

;; tanh as 1 - 2 / (e^2x + 1): exact to rounding at either end, and twice
;; as fast here as the C library's tanh, which does not vectorise
(define (ica-tanh x) (- 1.0 (/ 2.0 (+ (exp (* 2.0 x)) 1.0))))

;; W (m x m) <- (W W')^(-1/2) W; A V T are m x m scratch, EV E m
(define (ica-sym w a v ev e t m)
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j 0 (+ j 1))) ((= j m))
      (let ((acc 0.0))
        (do ((r 0 (+ r 1))) ((= r m))
          (set! acc (+ acc (* (vector-ref w (+ (* i m) r)) (vector-ref w (+ (* j m) r))))))
        (vector-set! a (+ (* i m) j) acc))))
  (sym-eigen a v ev e m)
  ;; T = u diag(1/sqrt s) u'
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j 0 (+ j 1))) ((= j m))
      (let ((acc 0.0))
        (do ((r 0 (+ r 1))) ((= r m))
          (let ((sr (if (< (vector-ref ev r) 2.2250738585072014e-308) 2.2250738585072014e-308 (vector-ref ev r))))
            (set! acc (+ acc (* (/ (vector-ref v (+ (* i m) r)) (sqrt sr)) (vector-ref v (+ (* j m) r)))))))
        (vector-set! t (+ (* i m) j) acc))))
  ;; A = T W, then back into W
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j 0 (+ j 1))) ((= j m))
      (let ((acc 0.0))
        (do ((r 0 (+ r 1))) ((= r m))
          (set! acc (+ acc (* (vector-ref t (+ (* i m) r)) (vector-ref w (+ (* r m) j))))))
        (vector-set! a (+ (* i m) j) acc))))
  (do ((t2 0 (+ t2 1))) ((= t2 (* m m))) (vector-set! w t2 (vector-ref a t2)))
  0)

(define (fastica x winit comps white unmix mean maxiter tol n p nc)
  (let ((xc (make-vector (* n p) 0.0))
        (g (make-vector (* p p) 0.0))
        (u (make-vector (* p p) 0.0))
        (ev (make-vector p 0.0))
        (ord (make-vector p 0))
        (x1 (make-vector (* nc n) 0.0))
        (gw (make-vector (* nc n) 0.0))
        (w1 (make-vector (* nc nc) 0.0))
        (gx (make-vector nc 0.0))
        (sa (make-vector (* nc nc) 0.0))
        (sv (make-vector (* nc nc) 0.0))
        (se (make-vector nc 0.0))
        (se2 (make-vector nc 0.0))
        (pe (make-vector p 0.0))
        (st (make-vector (* nc nc) 0.0))
        (it 0) (done 0))
    ;; centre, then the Gram X'X
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! mean j 0.0))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! mean j (+ (vector-ref mean j) (vector-ref x (+ (* i p) j))))))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! mean j (/ (vector-ref mean j) (exact->inexact n))))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! xc (+ (* i p) j) (- (vector-ref x (+ (* i p) j)) (vector-ref mean j)))))
    (with-arrays ((xc (n p)) (g (p p)))
      (array-set! g (matmul (transpose xc) xc)))
    (sym-eigen g u ev pe p)
    (eig-order ev ord p)
    ;; K = (u / d)', each column of u signed by its first entry
    (do ((c 0 (+ c 1))) ((= c nc))
      (let ((col (vector-ref ord c)))
        (let ((sg (if (< (vector-ref u col) 0.0) -1.0 (if (> (vector-ref u col) 0.0) 1.0 0.0)))
              (d (sqrt (vector-ref ev col))))
          (do ((j 0 (+ j 1))) ((= j p))
            (vector-set! white (+ (* c p) j) (/ (* sg (vector-ref u (+ (* j p) col))) d))))))
    (with-arrays ((white (nc p)) (xc (n p)) (x1 (nc n)))
      (array-set! x1 (matmul white (transpose xc))))
    (let ((sn (sqrt (exact->inexact n))))
      (do ((t 0 (+ t 1))) ((= t (* nc n))) (vector-set! x1 t (* (vector-ref x1 t) sn))))
    ;; the parallel iteration
    (do ((t 0 (+ t 1))) ((= t (* nc nc))) (vector-set! unmix t (vector-ref winit t)))
    (ica-sym unmix sa sv se se2 st nc)
    (do () ((or (= done 1) (>= it maxiter)))
      (with-arrays ((unmix (nc nc)) (x1 (nc n)) (gw (nc n)))
        (array-set! gw (matmul unmix x1)))
      (do ((c 0 (+ c 1))) ((= c nc))
        (let ((acc 0.0))
          (do ((i 0 (+ i 1))) ((= i n))
            (let ((th (ica-tanh (vector-ref gw (+ (* c n) i)))))
              (vector-set! gw (+ (* c n) i) th)
              (set! acc (+ acc (- 1.0 (* th th))))))
          (vector-set! gx c (/ acc (exact->inexact n)))))
      (with-arrays ((gw (nc n)) (x1 (nc n)) (w1 (nc nc)))
        (array-set! w1 (matmul gw (transpose x1))))
      (do ((c 0 (+ c 1))) ((= c nc))
        (do ((j 0 (+ j 1))) ((= j nc))
          (vector-set! w1 (+ (* c nc) j)
                       (- (/ (vector-ref w1 (+ (* c nc) j)) (exact->inexact n))
                          (* (vector-ref gx c) (vector-ref unmix (+ (* c nc) j)))))))
      (ica-sym w1 sa sv se se2 st nc)
      (let ((lim 0.0))
        (do ((c 0 (+ c 1))) ((= c nc))
          (let ((acc 0.0))
            (do ((j 0 (+ j 1))) ((= j nc))
              (set! acc (+ acc (* (vector-ref w1 (+ (* c nc) j)) (vector-ref unmix (+ (* c nc) j))))))
            (let ((dv (- (if (< acc 0.0) (- 0.0 acc) acc) 1.0)))
              (let ((av (if (< dv 0.0) (- 0.0 dv) dv)))
                (if (> av lim) (set! lim av) 0)))))
        (do ((t 0 (+ t 1))) ((= t (* nc nc))) (vector-set! unmix t (vector-ref w1 t)))
        (set! it (+ it 1))
        (if (< lim tol) (set! done 1) 0)))
    ;; unit variance: S = W K Xc', its rows' standard deviations divide W
    (do ((c 0 (+ c 1))) ((= c nc))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((acc 0.0))
          (do ((r 0 (+ r 1))) ((= r nc))
            (set! acc (+ acc (* (vector-ref unmix (+ (* c nc) r)) (vector-ref white (+ (* r p) j))))))
          (vector-set! comps (+ (* c p) j) acc))))
    (with-arrays ((comps (nc p)) (xc (n p)) (gw (nc n)))
      (array-set! gw (matmul comps (transpose xc))))
    (do ((c 0 (+ c 1))) ((= c nc))
      (let ((m1 0.0) (v1 0.0))
        (do ((i 0 (+ i 1))) ((= i n)) (set! m1 (+ m1 (vector-ref gw (+ (* c n) i)))))
        (set! m1 (/ m1 (exact->inexact n)))
        (do ((i 0 (+ i 1))) ((= i n))
          (let ((dd (- (vector-ref gw (+ (* c n) i)) m1)))
            (set! v1 (+ v1 (* dd dd)))))
        (let ((sd (sqrt (/ v1 (exact->inexact n)))))
          (do ((j 0 (+ j 1))) ((= j nc))
            (vector-set! unmix (+ (* c nc) j) (/ (vector-ref unmix (+ (* c nc) j)) sd))))))
    (do ((c 0 (+ c 1))) ((= c nc))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((acc 0.0))
          (do ((r 0 (+ r 1))) ((= r nc))
            (set! acc (+ acc (* (vector-ref unmix (+ (* c nc) r)) (vector-ref white (+ (* r p) j))))))
          (vector-set! comps (+ (* c p) j) acc))))
    it))

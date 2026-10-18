;;;; The graphical lasso, whole: scikit-learn's _graphical_lasso in mode
;;;; "cd" with its inner solver enet_coordinate_descent_gram, written out
;;;; in the subset.
;;;;
;;;;   max_Theta  log det Theta - tr(S Theta) - alpha ||Theta||_1,off
;;;;
;;;; S is the empirical covariance (EMP, p by p).  The start is S with
;;;; its off-diagonal scaled by 0.95, inverted (scikit-learn's pinvh;
;;;; here a Cholesky inverse, the start being positive definite).  Each
;;;; iteration visits the columns: for column idx, the lasso
;;;;   min_b  1/2 b' W11 b - s12' b + alpha |b|_1
;;;; over the covariance W11 of the other columns (SUB, kept current a
;;;; row and a column at a time as idx moves) is solved warm from the
;;;; precision's column, and the column of the precision and of the
;;;; covariance are updated from b.  An iteration ends with the dual gap
;;;; tr(S Theta) - p + alpha (|Theta|_1 - |diag Theta|_1); the fit stops
;;;; when it falls below TOL, or after MAXITER iterations.
;;;;
;;;; The inner solver is enet_coordinate_descent_gram with beta = 0, no
;;;; random order and scikit-learn's gap-safe rule (Ndiaye et al. 2017):
;;;; coordinates the duality gap proves zero leave the active set, and
;;;; a sweep whose largest move is within ENETTOL of the largest
;;;; coefficient checks the gap against ENETTOL |s12|^2.  scikit-learn
;;;; also computes the objective (a log-determinant) every iteration for
;;;; its costs_; that is a report, not part of the iteration, and is not
;;;; computed here.
;;;;
;;;; The two matrix-vector products of a column -- Q w in the inner
;;;; solver's start and W11 b after it -- are written as products, so
;;;; that --blas hands them to dgemv as scikit-learn's np.dot does; the
;;;; rest is loops.  COV and PREC come back with the covariance and the
;;;; precision.  Returns the number of iterations.
;;;;

;; INV = A^-1 for a positive definite A (P x P), through its Cholesky
;; factor L (scratch, P x P) and two triangular solves per column
(define (spd-inverse a inv l z p)
  (do ((j 0 (+ j 1))) ((= j p))
    (let ((s (vector-ref a (+ (* j p) j))))
      (do ((k 0 (+ k 1))) ((= k j))
        (set! s (- s (* (vector-ref l (+ (* j p) k)) (vector-ref l (+ (* j p) k))))))
      (vector-set! l (+ (* j p) j) (sqrt s))
      (do ((i (+ j 1) (+ i 1))) ((>= i p))
        (let ((t (vector-ref a (+ (* i p) j))))
          (do ((k 0 (+ k 1))) ((= k j))
            (set! t (- t (* (vector-ref l (+ (* i p) k)) (vector-ref l (+ (* j p) k))))))
          (vector-set! l (+ (* i p) j) (/ t (vector-ref l (+ (* j p) j))))))))
  (do ((c 0 (+ c 1))) ((= c p))
    ;; L z = e_c
    (do ((i 0 (+ i 1))) ((= i p))
      (let ((t (if (= i c) 1.0 0.0)))
        (do ((k 0 (+ k 1))) ((= k i))
          (set! t (- t (* (vector-ref l (+ (* i p) k)) (vector-ref z k)))))
        (vector-set! z i (/ t (vector-ref l (+ (* i p) i))))))
    ;; L' x = z, x into column c
    (do ((ii 0 (+ ii 1))) ((= ii p))
      (let ((i (- (- p 1) ii)))
        (let ((t (vector-ref z i)))
          (do ((k (+ i 1) (+ k 1))) ((>= k p))
            (set! t (- t (* (vector-ref l (+ (* k p) i)) (vector-ref inv (+ (* k p) c))))))
          (vector-set! inv (+ (* i p) c) (/ t (vector-ref l (+ (* i p) i))))))))
  0)

;; the duality gap of the inner lasso (scikit-learn's gap_enet_gram with
;; beta = 0, formulation A); XTA gets q - Qw, OUT[0] the gap and OUT[1]
;; the dual norm max |XtA|
(define (enet-gap w q qw xta out alpha ynorm2 m)
  (let ((qdotw 0.0) (wqw 0.0) (l1 0.0) (dn 0.0))
    (do ((j 0 (+ j 1))) ((= j m))
      (let ((wj (vector-ref w j)))
        (set! qdotw (+ qdotw (* wj (vector-ref q j))))
        (set! wqw (+ wqw (* wj (vector-ref qw j))))
        (set! l1 (+ l1 (if (< wj 0.0) (- 0.0 wj) wj)))
        (let ((x (- (vector-ref q j) (vector-ref qw j))))
          (vector-set! xta j x)
          (let ((ax (if (< x 0.0) (- 0.0 x) x)))
            (if (> ax dn) (set! dn ax) 0)))))
    (let ((rnorm2 (- (+ ynorm2 wqw) (* 2.0 qdotw)))
          (ry (- ynorm2 qdotw)))
      (let ((scale (if (> dn alpha) (/ alpha dn) 1.0)))
        (vector-set! out 0 (- (+ (* 0.5 rnorm2) (* alpha l1))
                              (+ (* -0.5 (* (* scale scale) rnorm2)) (* scale ry))))
        (vector-set! out 1 dn))))
  0)

;; the gap-safe rule: over the coordinates not yet excluded, keep those
;; the gap cannot prove zero, drop the rest (moving Qw back); returns the
;; new active count
(define (enet-safe-rule w qm qw xta active excl out alpha m)
  (let ((radius (/ (sqrt (* 2.0 (let ((g (vector-ref out 0))) (if (< g 0.0) (- 0.0 g) g)))) alpha))
        (dn (vector-ref out 1))
        (nact 0))
    (do ((j 0 (+ j 1))) ((= j m))
      (if (= (vector-ref excl j) 0)
          (let ((xjt (/ (vector-ref xta j) (if (> alpha dn) alpha dn))))
            (let ((dj (/ (- 1.0 (if (< xjt 0.0) (- 0.0 xjt) xjt))
                         (sqrt (vector-ref qm (+ (* j m) j))))))
              (if (<= dj radius)
                  (begin (vector-set! active nact j) (set! nact (+ nact 1)))
                  (begin
                    (if (not (= (vector-ref w j) 0.0))
                        (let ((wj (vector-ref w j)))
                          (do ((r 0 (+ r 1))) ((= r m))
                            (vector-set! qw r (- (vector-ref qw r) (* wj (vector-ref qm (+ (* j m) r))))))
                          (vector-set! w j 0.0))
                        0)
                    (vector-set! excl j 1)))))
          0))
    nact))

;; scikit-learn's enet_coordinate_descent_gram for beta = 0, positive
;; off, random off, the gap-safe rule on: min 1/2 w'Qw - q'w + alpha|w|_1
;; with y = q.  W is the warm start and comes back solved.
(define (enet-gram w qm q qw xta active excl out alpha maxiter tol m)
  (let ((ynorm2 0.0) (dwtol tol) (nact 0) (done 0) (iter 0))
    (do ((j 0 (+ j 1))) ((= j m))
      (set! ynorm2 (+ ynorm2 (* (vector-ref q j) (vector-ref q j))))
      (vector-set! excl j 0))
    ;; Qw = Q w, as a product so that --blas makes it a gemv (a reduction
    ;; the compiler cannot vectorise as a loop, being bound to its order)
    (with-arrays ((qm (m m)) (w (m)) (qw (m)))
      (array-set! qw (matmul qm w)))
    (let ((gtol (* tol ynorm2)))
      (enet-gap w q qw xta out alpha ynorm2 m)
      (if (and (>= (vector-ref out 0) 0.0) (<= (vector-ref out 0) gtol))
          (set! done 1)
          (begin
            ;; the initial rule: zero diagonals are excluded outright
            (do ((j 0 (+ j 1))) ((= j m))
              (if (= (vector-ref qm (+ (* j m) j)) 0.0)
                  (begin (vector-set! w j 0.0) (vector-set! excl j 1))
                  0))
            (set! nact (enet-safe-rule w qm qw xta active excl out alpha m))))
      (do () ((or (= done 1) (>= iter maxiter)))
        (let ((wmax 0.0) (dwmax 0.0))
          (do ((f 0 (+ f 1))) ((= f nact))
            (let ((j (vector-ref active f)))
              (let ((qjj (vector-ref qm (+ (* j m) j))))
                (if (not (= qjj 0.0))
                    (let ((wj (vector-ref w j)))
                      (let ((tmp (+ (- (vector-ref q j) (vector-ref qw j)) (* wj qjj))))
                        (let ((mag (- (if (< tmp 0.0) (- 0.0 tmp) tmp) alpha)))
                          (let ((wn (if (> mag 0.0) (/ (if (< tmp 0.0) (- 0.0 mag) mag) qjj) 0.0)))
                            (vector-set! w j wn)
                            (if (not (= wn wj))
                                (do ((r 0 (+ r 1))) ((= r m))
                                  (vector-set! qw r (+ (vector-ref qw r) (* (- wn wj) (vector-ref qm (+ (* j m) r))))))
                                0)
                            (let ((dw (if (< wn wj) (- wj wn) (- wn wj)))
                                  (aw (if (< wn 0.0) (- 0.0 wn) wn)))
                              (if (> dw dwmax) (set! dwmax dw) 0)
                              (if (> aw wmax) (set! wmax aw) 0))))))
                    0))))
          (if (or (= wmax 0.0) (<= (/ dwmax wmax) dwtol) (= iter (- maxiter 1)))
              (begin
                (enet-gap w q qw xta out alpha ynorm2 m)
                (if (<= (vector-ref out 0) gtol)
                    (set! done 1)
                    (set! nact (enet-safe-rule w qm qw xta active excl out alpha m))))
              0)
          (set! iter (+ iter 1)))))
    iter))

(define (graphical-lasso emp cov prec alpha maxiter tol enettol p)
  (let ((m (- p 1)))
    (let ((sub (make-vector (* m m) 0.0))
          (row (make-vector m 0.0))
          (b (make-vector m 0.0))
          (bnew (make-vector m 0.0))
          (qw (make-vector m 0.0))
          (xta (make-vector m 0.0))
          (active (make-vector m 0))
          (excl (make-vector m 0))
          (out (make-vector 2 0.0))
          (l (make-vector (* p p) 0.0))
          (z (make-vector p 0.0))
          (done 0) (it 0)
          (innermax (if (> maxiter 20) maxiter 20)))
      ;; the start: S with its off-diagonal scaled by 0.95, inverted
      (do ((i 0 (+ i 1))) ((= i p))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! cov (+ (* i p) j)
                       (if (= i j) (vector-ref emp (+ (* i p) j)) (* 0.95 (vector-ref emp (+ (* i p) j)))))))
      (spd-inverse cov prec l z p)
      (do () ((or (= done 1) (>= it maxiter)))
        (do ((idx 0 (+ idx 1))) ((= idx p))
          ;; SUB = the covariance without row and column idx, kept current
          (if (> idx 0)
              (let ((di (- idx 1)))
                (do ((s 0 (+ s 1))) ((= s m))
                  (let ((o (if (< s idx) s (+ s 1))))
                    (vector-set! sub (+ (* di m) s) (vector-ref cov (+ (* di p) o)))
                    (vector-set! sub (+ (* s m) di) (vector-ref cov (+ (* o p) di))))))
              (do ((s 0 (+ s 1))) ((= s m))
                (do ((t 0 (+ t 1))) ((= t m))
                  (vector-set! sub (+ (* s m) t) (vector-ref cov (+ (* (+ s 1) p) (+ t 1)))))))
          ;; the lasso of column idx, warm from the precision's column
          (let ((pii (vector-ref prec (+ (* idx p) idx))))
            (do ((s 0 (+ s 1))) ((= s m))
              (let ((o (if (< s idx) s (+ s 1))))
                (vector-set! row s (vector-ref emp (+ (* idx p) o)))
                (vector-set! b s (- 0.0 (/ (vector-ref prec (+ (* o p) idx))
                                            (+ pii (* 1000.0 2.220446049250313e-16))))))))
          (enet-gram b sub row qw xta active excl out alpha innermax enettol m)
          ;; the precision's column, then the covariance's, from b
          (let ((acc 0.0))
            (do ((s 0 (+ s 1))) ((= s m))
              (let ((o (if (< s idx) s (+ s 1))))
                (set! acc (+ acc (* (vector-ref cov (+ (* o p) idx)) (vector-ref b s))))))
            (let ((pnew (/ 1.0 (- (vector-ref cov (+ (* idx p) idx)) acc))))
              (vector-set! prec (+ (* idx p) idx) pnew)
              (do ((s 0 (+ s 1))) ((= s m))
                (let ((o (if (< s idx) s (+ s 1))))
                  (vector-set! prec (+ (* o p) idx) (- 0.0 (* pnew (vector-ref b s))))
                  (vector-set! prec (+ (* idx p) o) (- 0.0 (* pnew (vector-ref b s))))))))
          (with-arrays ((sub (m m)) (b (m)) (bnew (m)))
            (array-set! bnew (matmul sub b)))
          (do ((s 0 (+ s 1))) ((= s m))
            (let ((o (if (< s idx) s (+ s 1))))
              (vector-set! cov (+ (* idx p) o) (vector-ref bnew s))
              (vector-set! cov (+ (* o p) idx) (vector-ref bnew s)))))
        ;; the dual gap: tr(S Theta) - p + alpha (|Theta|_1 - |diag Theta|_1)
        (let ((tr 0.0) (offl1 0.0))
          (do ((i 0 (+ i 1))) ((= i p))
            (do ((j 0 (+ j 1))) ((= j p))
              (let ((t (vector-ref prec (+ (* i p) j))))
                (set! tr (+ tr (* (vector-ref emp (+ (* i p) j)) t)))
                (if (not (= i j)) (set! offl1 (+ offl1 (if (< t 0.0) (- 0.0 t) t))) 0))))
          (let ((gap (+ (- tr (* 1.0 p)) (* alpha offl1))))
            (set! it (+ it 1))
            (if (< (if (< gap 0.0) (- 0.0 gap) gap) tol) (set! done 1) 0))))
      it)))

;;;; Theil-Sen regression, whole: scikit-learn's TheilSenRegressor -- the
;;;; least squares fit of every subset (_lstsq) and the spatial median of
;;;; the fits by the modified Weiszfeld iteration (_spatial_median) --
;;;; written out in the subset.
;;;;
;;;; IDX holds NSUB subsets of NS row indices (scikit-learn's: all the
;;;; combinations when there are at most max_subpopulation of them, else
;;;; random_state.choice draws, which the caller makes).  Each subset's
;;;; fit, with a ones column in front when FITINT is 1 (d = p + FITINT
;;;; unknowns): for NS = d the square system solved by Gaussian
;;;; elimination with partial pivoting -- the exact solution gelss also
;;;; finds -- and, when a pivot vanishes or NS > d, the minimum-norm least
;;;; squares solution as gelss gives it, pinvh(A'A) A'b through
;;;; sym-eigen.scm (its cutoff, d eps max|ev|, decides the rank on the
;;;; squared singular values: exact for duplicated or collinear rows,
;;;; coarser than gelss for nearly singular ones).  The spatial median starts at the
;;;; fits' mean; a step moves to the 1/distance-weighted mean of the fits
;;;; (fits within eps of the point left out, and the step damped by
;;;; their presence as Kaerkkaeinen and Aeyraemoe damp it); it stops when
;;;; the point moves by less than TOL, or after MAXITER steps.  With one
;;;; unknown the median is the plain median (scikit-learn's shortcut).
;;;;
;;;; X has rows of p (those IDX names).  COEF (d) gets the median: the intercept first
;;;; when FITINT is 1.  W (NSUB x d) gets the subsets' fits.  Returns
;;;; n_iter_ (the index of the last step, as scikit-learn reports it).
;;;;

(include "sym-eigen.scm")

;; the minimum-norm least squares fit of subset S into row S of W:
;; pinv(A) b = pinvh(A'A) A'b, eigenvalues of A'A at most d eps max|ev|
;; dropped.  AA, V (d x d), EV, E, AB (d) scratch
(define (ts-minnorm x y idx w aa v ev e ab s ns fitint p d)
  (do ((t 0 (+ t 1))) ((= t (* d d))) (vector-set! aa t 0.0))
  (do ((t 0 (+ t 1))) ((= t d)) (vector-set! ab t 0.0))
  (do ((r 0 (+ r 1))) ((= r ns))
    (let ((i (vector-ref idx (+ (* s ns) r))))
      (do ((u 0 (+ u 1))) ((= u d))
        (let ((xu (if (< u fitint) 1.0 (vector-ref x (+ (* i p) (- u fitint))))))
          (vector-set! ab u (+ (vector-ref ab u) (* xu (vector-ref y i))))
          (do ((q 0 (+ q 1))) ((= q d))
            (let ((xq (if (< q fitint) 1.0 (vector-ref x (+ (* i p) (- q fitint))))))
              (vector-set! aa (+ (* u d) q) (+ (vector-ref aa (+ (* u d) q)) (* xu xq)))))))))
  (sym-eigen aa v ev e d)
  (let ((mx 0.0))
    (do ((r 0 (+ r 1))) ((= r d))
      (if (> (ts-abs (vector-ref ev r)) mx) (set! mx (ts-abs (vector-ref ev r))) 0))
    (let ((cut (* mx (* (exact->inexact d) 2.220446049250313e-16))))
      (do ((u 0 (+ u 1))) ((= u d))
        (let ((acc 0.0))
          (do ((r 0 (+ r 1))) ((= r d))
            (if (> (ts-abs (vector-ref ev r)) cut)
                (let ((vab 0.0))
                  (do ((q 0 (+ q 1))) ((= q d))
                    (set! vab (+ vab (* (vector-ref v (+ (* q d) r)) (vector-ref ab q)))))
                  (set! acc (+ acc (/ (* (vector-ref v (+ (* u d) r)) vab) (vector-ref ev r)))))
                0))
          (vector-set! w (+ (* s d) u) acc)))))
  0)

;; one subset's fit into row S of W: the square system by Gaussian
;; elimination with partial pivoting, the minimum-norm fit when a pivot
;; vanishes or the subset has more rows than unknowns.  A (d x d), B (d)
;; and the minimum-norm scratch
(define (ts-fit x y idx w a b aa v ev e ab s ns fitint p d)
  (let ((singular 0) (scale 0.0))
    (if (= ns d)
        (begin
          (do ((r 0 (+ r 1))) ((= r d))
            (let ((i (vector-ref idx (+ (* s ns) r))))
              (if (= fitint 1) (vector-set! a (* r d) 1.0) 0)
              (do ((j 0 (+ j 1))) ((= j p))
                (vector-set! a (+ (* r d) (+ j fitint)) (vector-ref x (+ (* i p) j))))
              (vector-set! b r (vector-ref y i))))
          (do ((t 0 (+ t 1))) ((= t (* d d)))
            (if (> (ts-abs (vector-ref a t)) scale) (set! scale (ts-abs (vector-ref a t))) 0))
          (do ((c 0 (+ c 1))) ((= c d))
            ;; the pivot: the largest magnitude in column c, from row c down
            (let ((piv c) (big (ts-abs (vector-ref a (+ (* c d) c)))))
              (do ((r (+ c 1) (+ r 1))) ((>= r d))
                (if (> (ts-abs (vector-ref a (+ (* r d) c))) big)
                    (begin (set! big (ts-abs (vector-ref a (+ (* r d) c)))) (set! piv r))
                    0))
              (if (<= big (* scale (* (exact->inexact d) 2.220446049250313e-16)))
                  (set! singular 1)
                  (begin
                    (if (not (= piv c))
                        (begin
                          (do ((j 0 (+ j 1))) ((= j d))
                            (let ((tmp (vector-ref a (+ (* c d) j))))
                              (vector-set! a (+ (* c d) j) (vector-ref a (+ (* piv d) j)))
                              (vector-set! a (+ (* piv d) j) tmp)))
                          (let ((tb (vector-ref b c)))
                            (vector-set! b c (vector-ref b piv))
                            (vector-set! b piv tb)))
                        0)
                    (do ((r (+ c 1) (+ r 1))) ((>= r d))
                      (let ((fct (/ (vector-ref a (+ (* r d) c)) (vector-ref a (+ (* c d) c)))))
                        (do ((j c (+ j 1))) ((= j d))
                          (vector-set! a (+ (* r d) j) (- (vector-ref a (+ (* r d) j)) (* fct (vector-ref a (+ (* c d) j))))))
                        (vector-set! b r (- (vector-ref b r) (* fct (vector-ref b c))))))))))
          (if (= singular 0)
              (do ((cc 0 (+ cc 1))) ((= cc d))
                (let ((c (- (- d 1) cc)))
                  (let ((t (vector-ref b c)))
                    (do ((j (+ c 1) (+ j 1))) ((>= j d))
                      (set! t (- t (* (vector-ref a (+ (* c d) j)) (vector-ref w (+ (* s d) j))))))
                    (vector-set! w (+ (* s d) c) (/ t (vector-ref a (+ (* c d) c)))))))
              0))
        (set! singular 1))
    (if (= singular 1)
        (ts-minnorm x y idx w aa v ev e ab s ns fitint p d)
        0))
  0)

(define (ts-abs v) (if (< v 0.0) (- 0.0 v) v))

(define (theilsen x y idx w coef nsub ns fitint maxiter tol p)
  (let ((d (+ p fitint))
        (it 0))
    (let ((a (make-vector (* d d) 0.0))
          (b (make-vector d 0.0))
          (aa (make-vector (* d d) 0.0))
          (v (make-vector (* d d) 0.0))
          (ev (make-vector d 0.0))
          (e (make-vector d 0.0))
          (ab (make-vector d 0.0))
          (old (make-vector d 0.0))
          (num (make-vector d 0.0))
          (qv (make-vector d 0.0))
          (eps 2.220446049250313e-16))
      (do ((s 0 (+ s 1))) ((= s nsub))
        (ts-fit x y idx w a b aa v ev e ab s ns fitint p d))
      (if (= d 1)
          ;; the plain median of the fits
          (let ((v (make-vector nsub 0.0)))
            (do ((s 0 (+ s 1))) ((= s nsub)) (vector-set! v s (vector-ref w s)))
            (do ((s 1 (+ s 1))) ((= s nsub))
              (let ((key (vector-ref v s)) (j (- s 1)))
                (do () ((or (< j 0) (<= (vector-ref v j) key)))
                  (vector-set! v (+ j 1) (vector-ref v j))
                  (set! j (- j 1)))
                (vector-set! v (+ j 1) key)))
            (vector-set! coef 0 (if (= (remainder nsub 2) 1)
                                    (vector-ref v (quotient nsub 2))
                                    (* 0.5 (+ (vector-ref v (- (quotient nsub 2) 1)) (vector-ref v (quotient nsub 2))))))
            (set! it 1))
          (let ((tol2 (* tol tol)) (done 0))
            (do ((j 0 (+ j 1))) ((= j d))
              (let ((acc 0.0))
                (do ((s 0 (+ s 1))) ((= s nsub)) (set! acc (+ acc (vector-ref w (+ (* s d) j)))))
                (vector-set! old j (/ acc (exact->inexact nsub)))))
            (do () ((or (= done 1) (>= it maxiter)))
              ;; the modified Weiszfeld step from OLD
              (let ((inx 0) (sinv 0.0))
                (do ((j 0 (+ j 1))) ((= j d))
                  (vector-set! num j 0.0)
                  (vector-set! qv j 0.0))
                (do ((s 0 (+ s 1))) ((= s nsub))
                  (let ((dn 0.0))
                    (do ((j 0 (+ j 1))) ((= j d))
                      (let ((df (- (vector-ref w (+ (* s d) j)) (vector-ref old j))))
                        (set! dn (+ dn (* df df)))))
                    (set! dn (sqrt dn))
                    (if (>= dn eps)
                        (begin
                          (set! sinv (+ sinv (/ 1.0 dn)))
                          (do ((j 0 (+ j 1))) ((= j d))
                            (vector-set! qv j (+ (vector-ref qv j) (/ (- (vector-ref w (+ (* s d) j)) (vector-ref old j)) dn)))
                            (vector-set! num j (+ (vector-ref num j) (/ (vector-ref w (+ (* s d) j)) dn)))))
                        (set! inx 1))))
                (let ((qn 0.0))
                  (do ((j 0 (+ j 1))) ((= j d)) (set! qn (+ qn (* (vector-ref qv j) (vector-ref qv j)))))
                  (set! qn (sqrt qn))
                  (let ((usedir (if (> qn eps) 1 0)))
                    (let ((qn2 (if (= usedir 1) qn 1.0)) (moved 0.0))
                      (let ((wa (let ((t5 (- 1.0 (/ (exact->inexact inx) qn2)))) (if (> t5 0.0) t5 0.0)))
                            (wb (let ((t6 (/ (exact->inexact inx) qn2))) (if (< t6 1.0) t6 1.0))))
                        (do ((j 0 (+ j 1))) ((= j d))
                          (let ((nd (if (= usedir 1) (/ (vector-ref num j) sinv) 1.0)))
                            (let ((nw (+ (* wa nd) (* wb (vector-ref old j)))))
                              (set! moved (+ moved (* (- (vector-ref old j) nw) (- (vector-ref old j) nw))))
                              (vector-set! coef j nw)))))
                      (if (< moved tol2)
                          (set! done 1)
                          (begin
                            (do ((j 0 (+ j 1))) ((= j d)) (vector-set! old j (vector-ref coef j)))
                            (set! it (+ it 1))))))))))))
      it))

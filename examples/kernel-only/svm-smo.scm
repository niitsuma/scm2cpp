;;;; libsvm's solver for C-SVC, whole: Solver::Solve of libsvm (Chang and
;;;; Lin), the code scikit-learn's SVC runs, written out in the subset.
;;;;
;;;;   min_a  1/2 a'Qa - sum a,   0 <= a_i <= C,   y'a = 0,
;;;;   Q_ij = y_i y_j K_ij
;;;;
;;;; Each iteration moves two alphas: the pair the second-order working
;;;; set selection picks (WSS3, Fan, Chen and Lin 2005) -- i the most
;;;; violating index from above, j the one whose step decreases the
;;;; objective most with i -- and the gradient G = Qa - 1 is updated by
;;;; two kernel rows.  The fit ends when the maximal violation
;;;; Gmax + Gmax2 is below EPS (SVC's tol).  Every min(n, 1000)
;;;; iterations the solver shrinks: an alpha at a bound whose gradient
;;;; keeps it there is moved past the end of the active part, so the
;;;; selection and the gradient update run over the rest; G_bar, the
;;;; gradient's part from the alphas at C, lets the full gradient be
;;;; rebuilt when they come back (once the violation is within 10 EPS,
;;;; and before the final test).  RHO is the bias: the mean of y_i G_i
;;;; over the free alphas, b = -rho, so f(x) = sum a_i y_i K(x_i, x) - rho.
;;;;
;;;; K is the whole kernel matrix, n rows of n, in the caller's order --
;;;; libsvm with a kernel cache large enough for every row.  The solver
;;;; works on positions; INDEX maps a position to its point, and the
;;;; swaps that shrinking does permute the positions, not K.  ALPHA comes
;;;; back in the caller's order, RHO in RHO[0]; the return value is the
;;;; number of iterations.
;;;;

(define (svm-smo k y alpha rho cost iters eps n)
  ;; the labels, the alphas and the bias go through working vectors of
  ;; their own, so the caller may hold them in arrays of any kind;
  ;; svr-smo hands the solver vectors of length 2N
  (let ((lin (make-vector n -1.0))
        (yv (make-vector n 0.0))
        (av (make-vector n 0.0))
        (rv (make-vector 1 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! yv i (vector-ref y i)))
    (let ((it (smo-solve k yv lin av rv cost iters eps n n)))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! alpha i (vector-ref av i)))
      (vector-set! rho 0 (vector-ref rv 0))
      it)))

;; libsvm's Solver itself, for any of its problems:
;;   min_a  1/2 a'Qa + lin'a,  0 <= a_i <= C,  y'a = 0,
;;   Q_ij = y_i y_j K[r_i, r_j]
;; over N variables, K being NK x NK and r_i = i mod NK the kernel row
;; of variable i.  C-SVC is LIN = -1, NK = N; epsilon-SVR is 2N
;; variables over the N points (svr-smo below).  KROW and PP carry r
;; and LIN by position, swapped with the rest.
(define (smo-solve k y lin alpha rho cost iters eps n nk)
  (let ((index (make-vector n 0))
        (krow (make-vector n 0))
        (pp (make-vector n 0.0))
        (yy (make-vector n 0.0))
        (a (make-vector n 0.0))
        (g (make-vector n 0.0))
        (gbar (make-vector n 0.0))
        (qd (make-vector n 0.0))
        (active n)
        (unshrink 0)
        (counter (+ (if (< n 1000) n 1000) 1))
        (iter 0)
        (done 0))
    ;; positions start as the variables; G = Qa + lin = lin at a = 0
    (do ((t 0 (+ t 1))) ((= t n))
      (vector-set! index t t)
      (vector-set! krow t (remainder t nk))
      (vector-set! pp t (vector-ref lin t))
      (vector-set! yy t (vector-ref y t))
      (vector-set! g t (vector-ref lin t))
      (vector-set! qd t (vector-ref k (+ (* (vector-ref krow t) nk) (vector-ref krow t)))))
    (do () ((or (= done 1) (>= iter iters)))
      ;; shrink every min(n, 1000) iterations
      (set! counter (- counter 1))
      (if (= counter 0)
          (begin
            (set! counter (if (< n 1000) n 1000))
            (let ((gmax1 -1e300) (gmax2 -1e300))
              (do ((t 0 (+ t 1))) ((= t active))
                (let ((gt (vector-ref g t)) (at (vector-ref a t)))
                  (if (> (vector-ref yy t) 0.0)
                      (begin
                        (if (and (< at cost) (> (- 0.0 gt) gmax1)) (set! gmax1 (- 0.0 gt)) 0)
                        (if (and (> at 0.0) (> gt gmax2)) (set! gmax2 gt) 0))
                      (begin
                        (if (and (< at cost) (> (- 0.0 gt) gmax2)) (set! gmax2 (- 0.0 gt)) 0)
                        (if (and (> at 0.0) (> gt gmax1)) (set! gmax1 gt) 0)))))
              ;; near the end, bring everything back once
              (if (and (= unshrink 0) (<= (+ gmax1 gmax2) (* eps 10.0)))
                  (begin
                    (set! unshrink 1)
                    (reconstruct-gradient k krow pp yy a g gbar cost active n nk)
                    (set! active n))
                  0)
              ;; out of the active part: a bound alpha the gradient
              ;; holds there by more than the current violation
              (let ((t 0))
                (do () ((>= t active))
                  (if (= (shrinkable? yy a g cost gmax1 gmax2 t) 1)
                      (begin
                        (set! active (- active 1))
                        (let ((found 0))
                          (do () ((or (= found 1) (<= active t)))
                            (if (= (shrinkable? yy a g cost gmax1 gmax2 active) 0)
                                (begin
                                  (swap-position index krow pp yy a g gbar qd t active)
                                  (set! found 1))
                                (set! active (- active 1)))))
                        (set! t (+ t 1)))
                      (set! t (+ t 1)))))))
          0)
      ;; the working set; when the active part is optimal, rebuild the
      ;; gradient over everything and look again
      (let ((wi (make-vector 2 0)))
        (if (= (select-working-set k krow yy a g qd cost eps active nk wi) 1)
            (begin
              (reconstruct-gradient k krow pp yy a g gbar cost active n nk)
              (set! active n)
              (if (= (select-working-set k krow yy a g qd cost eps active nk wi) 1)
                  (set! done 1)
                  (set! counter 1)))
            0)
        (if (= done 0)
            (let ((i (vector-ref wi 0)) (j (vector-ref wi 1)))
              (set! iter (+ iter 1))
              (let ((ai (vector-ref a i)) (aj (vector-ref a j))
                    (yi (vector-ref yy i)) (yj (vector-ref yy j))
                    (pi (vector-ref krow i)) (pj (vector-ref krow j)))
                (let ((qij (* (* yi yj) (vector-ref k (+ (* pi nk) pj))))
                      (ui (if (>= ai cost) 1 0))
                      (uj (if (>= aj cost) 1 0))
                      (ni ai) (nj aj))
                  ;; the two-variable step, clipped to the box along y'a = 0
                  (if (not (= yi yj))
                      (let ((quad (+ (+ (vector-ref qd i) (vector-ref qd j)) (* 2.0 qij))))
                        (if (<= quad 0.0) (set! quad 1e-12) 0)
                        (let ((delta (/ (- (- 0.0 (vector-ref g i)) (vector-ref g j)) quad))
                              (diff (- ai aj)))
                          (set! ni (+ ai delta))
                          (set! nj (+ aj delta))
                          (if (> diff 0.0)
                              (if (< nj 0.0) (begin (set! nj 0.0) (set! ni diff)) 0)
                              (if (< ni 0.0) (begin (set! ni 0.0) (set! nj (- 0.0 diff))) 0))
                          (if (> diff 0.0)
                              (if (> ni cost) (begin (set! ni cost) (set! nj (- cost diff))) 0)
                              (if (> nj cost) (begin (set! nj cost) (set! ni (+ cost diff))) 0))))
                      (let ((quad (- (+ (vector-ref qd i) (vector-ref qd j)) (* 2.0 qij))))
                        (if (<= quad 0.0) (set! quad 1e-12) 0)
                        (let ((delta (/ (- (vector-ref g i) (vector-ref g j)) quad))
                              (sum (+ ai aj)))
                          (set! ni (- ai delta))
                          (set! nj (+ aj delta))
                          (if (> sum cost)
                              (if (> ni cost) (begin (set! ni cost) (set! nj (- sum cost))) 0)
                              (if (< nj 0.0) (begin (set! nj 0.0) (set! ni sum)) 0))
                          (if (> sum cost)
                              (if (> nj cost) (begin (set! nj cost) (set! ni (- sum cost))) 0)
                              (if (< ni 0.0) (begin (set! ni 0.0) (set! nj sum)) 0)))))
                  (vector-set! a i ni)
                  (vector-set! a j nj)
                  ;; G += Q_i dai + Q_j daj over the active part
                  (let ((di (- ni ai)) (dj (- nj aj)))
                    (do ((t 0 (+ t 1))) ((= t active))
                      (let ((pt (vector-ref krow t)) (yt (vector-ref yy t)))
                        (vector-set! g t
                                     (+ (vector-ref g t)
                                        (* yt (+ (* (* yi di) (vector-ref k (+ (* pi nk) pt)))
                                                 (* (* yj dj) (vector-ref k (+ (* pj nk) pt)))))))))
                    ;; G_bar follows the alphas that reach or leave C
                    (if (not (= ui (if (>= ni cost) 1 0)))
                        (do ((t 0 (+ t 1))) ((= t n))
                          (vector-set! gbar t
                                       (+ (vector-ref gbar t)
                                          (* (if (= ui 1) (- 0.0 cost) cost)
                                             (* (* yi (vector-ref yy t))
                                                (vector-ref k (+ (* pi nk) (vector-ref krow t))))))))
                        0)
                    (if (not (= uj (if (>= nj cost) 1 0)))
                        (do ((t 0 (+ t 1))) ((= t n))
                          (vector-set! gbar t
                                       (+ (vector-ref gbar t)
                                          (* (if (= uj 1) (- 0.0 cost) cost)
                                             (* (* yj (vector-ref yy t))
                                                (vector-ref k (+ (* pj nk) (vector-ref krow t))))))))
                        0)))))
            0)))
    ;; the bias: the free alphas' y_i G_i, averaged, or the middle of
    ;; the bound ones' range when none is free
    (if (< active n)
        (begin
          (reconstruct-gradient k krow pp yy a g gbar cost active n nk)
          (set! active n))
        0)
    (let ((nfree 0) (sumfree 0.0) (ub 1e300) (lb -1e300))
      (do ((t 0 (+ t 1))) ((= t n))
        (let ((yg (* (vector-ref yy t) (vector-ref g t)))
              (at (vector-ref a t)) (yt (vector-ref yy t)))
          (if (>= at cost)
              (if (< yt 0.0)
                  (if (< yg ub) (set! ub yg) 0)
                  (if (> yg lb) (set! lb yg) 0))
              (if (<= at 0.0)
                  (if (> yt 0.0)
                      (if (< yg ub) (set! ub yg) 0)
                      (if (> yg lb) (set! lb yg) 0))
                  (begin
                    (set! nfree (+ nfree 1))
                    (set! sumfree (+ sumfree yg)))))))
      (vector-set! rho 0 (if (> nfree 0) (/ sumfree (* 1.0 nfree)) (/ (+ ub lb) 2.0))))
    ;; alpha back in the caller's order
    (do ((t 0 (+ t 1))) ((= t n))
      (vector-set! alpha (vector-ref index t) (vector-ref a t)))
    iter))

;; 1 when the alpha at position T sits at a bound its gradient holds it
;; to by more than the violation GMAX1 / GMAX2 (libsvm's be_shrunk)
(define (shrinkable? yy a g cost gmax1 gmax2 t)
  (let ((at (vector-ref a t)) (gt (vector-ref g t)) (yt (vector-ref yy t)))
    (if (>= at cost)
        (if (> yt 0.0)
            (if (> (- 0.0 gt) gmax1) 1 0)
            (if (> (- 0.0 gt) gmax2) 1 0))
        (if (<= at 0.0)
            (if (> yt 0.0)
                (if (> gt gmax2) 1 0)
                (if (> gt gmax1) 1 0))
            0))))

;; exchange positions S and T (libsvm's swap_index; K stays put)
(define (swap-position index krow pp yy a g gbar qd s t)
  (let ((i0 (vector-ref index s)) (y0 (vector-ref yy s)) (a0 (vector-ref a s))
        (g0 (vector-ref g s)) (b0 (vector-ref gbar s)) (q0 (vector-ref qd s))
        (r0 (vector-ref krow s)) (p0 (vector-ref pp s)))
    (vector-set! index s (vector-ref index t)) (vector-set! index t i0)
    (vector-set! krow s (vector-ref krow t)) (vector-set! krow t r0)
    (vector-set! pp s (vector-ref pp t)) (vector-set! pp t p0)
    (vector-set! yy s (vector-ref yy t)) (vector-set! yy t y0)
    (vector-set! a s (vector-ref a t)) (vector-set! a t a0)
    (vector-set! g s (vector-ref g t)) (vector-set! g t g0)
    (vector-set! gbar s (vector-ref gbar t)) (vector-set! gbar t b0)
    (vector-set! qd s (vector-ref qd t)) (vector-set! qd t q0)
    0))

;; the gradient of the positions past ACTIVE, from G_bar and the free
;; alphas of the active part (libsvm's reconstruct_gradient)
(define (reconstruct-gradient k krow pp yy a g gbar cost active n nk)
  (do ((t active (+ t 1))) ((>= t n))
    (vector-set! g t (+ (vector-ref gbar t) (vector-ref pp t))))
  (do ((s 0 (+ s 1))) ((>= s active))
    (let ((as (vector-ref a s)))
      (if (and (> as 0.0) (< as cost))
          (let ((ps (vector-ref krow s)) (ys (vector-ref yy s)))
            (do ((t active (+ t 1))) ((>= t n))
              (vector-set! g t
                           (+ (vector-ref g t)
                              (* as (* (* ys (vector-ref yy t))
                                       (vector-ref k (+ (* ps nk) (vector-ref krow t)))))))))
          0)))
  0)

;; WSS3: i the maximal violator from above, j the partner whose step
;; with i lowers the objective most; WI gets (i j).  1 when the
;; violation is below EPS (optimal), else 0.
(define (select-working-set k krow yy a g qd cost eps active nk wi)
  (let ((gmax -1e300) (gmaxi -1) (gmax2 -1e300) (gmini -1) (objmin 1e300))
    (do ((t 0 (+ t 1))) ((= t active))
      (let ((gt (vector-ref g t)) (at (vector-ref a t)))
        (if (> (vector-ref yy t) 0.0)
            (if (and (< at cost) (>= (- 0.0 gt) gmax)) (begin (set! gmax (- 0.0 gt)) (set! gmaxi t)) 0)
            (if (and (> at 0.0) (>= gt gmax)) (begin (set! gmax gt) (set! gmaxi t)) 0))))
    (if (>= gmaxi 0)
        (let ((pi (vector-ref krow gmaxi)) (yi (vector-ref yy gmaxi)) (qdi (vector-ref qd gmaxi)))
          (do ((t 0 (+ t 1))) ((= t active))
            (let ((gt (vector-ref g t)) (at (vector-ref a t)) (yt (vector-ref yy t)))
              (if (> yt 0.0)
                  (if (> at 0.0)
                      (let ((gd (+ gmax gt)))
                        (if (>= gt gmax2) (set! gmax2 gt) 0)
                        (if (> gd 0.0)
                            (let ((quad (- (+ qdi (vector-ref qd t))
                                           (* 2.0 (* yi (* yi (* yt (vector-ref k (+ (* pi nk) (vector-ref krow t))))))))))
                              (let ((obj (/ (- 0.0 (* gd gd)) (if (> quad 0.0) quad 1e-12))))
                                (if (<= obj objmin) (begin (set! objmin obj) (set! gmini t)) 0)))
                            0))
                      0)
                  (if (< at cost)
                      (let ((gd (- gmax gt)))
                        (if (>= (- 0.0 gt) gmax2) (set! gmax2 (- 0.0 gt)) 0)
                        (if (> gd 0.0)
                            (let ((quad (+ (+ qdi (vector-ref qd t))
                                           (* 2.0 (* yi (* yi (* yt (vector-ref k (+ (* pi nk) (vector-ref krow t))))))))))
                              (let ((obj (/ (- 0.0 (* gd gd)) (if (> quad 0.0) quad 1e-12))))
                                (if (<= obj objmin) (begin (set! objmin obj) (set! gmini t)) 0)))
                            0))
                      0)))))
        0)
    (vector-set! wi 0 gmaxi)
    (vector-set! wi 1 gmini)
    (if (or (< (+ gmax gmax2) eps) (< gmini 0)) 1 0)))

;; epsilon-SVR by the same solver (libsvm's solve_epsilon_svr): the
;; variables alpha_i and alpha*_i of the N points become 2N, with signs
;; +1 and -1 and linear terms EPSILON - z_i and EPSILON + z_i; BETA gets
;; alpha_i - alpha*_i, RHO the bias, so f(x) = sum beta_i K(x_i, x) -
;; rho.  K is N x N.  Returns the iteration count.
(define (svr-smo k z beta rho cost epsilon iters eps n)
  (let ((y2 (make-vector (* 2 n) 0.0))
        (lin (make-vector (* 2 n) 0.0))
        (a2 (make-vector (* 2 n) 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! y2 i 1.0)
      (vector-set! y2 (+ i n) -1.0)
      (vector-set! lin i (- epsilon (vector-ref z i)))
      (vector-set! lin (+ i n) (+ epsilon (vector-ref z i))))
    (let ((rv (make-vector 1 0.0)))
      (let ((it (smo-solve k y2 lin a2 rv cost iters eps (* 2 n) n)))
        (do ((i 0 (+ i 1))) ((= i n))
          (vector-set! beta i (- (vector-ref a2 i) (vector-ref a2 (+ i n)))))
        (vector-set! rho 0 (vector-ref rv 0))
        it))))

;; The RBF kernel matrix from the products G = A B' (a matrix product,
;; formed by the caller's BLAS), in place: G_ij becomes
;; exp(-GAMMA max(|a_i|^2 + |b_j|^2 - 2 G_ij, 0)), SA and SB the
;; squared row norms, A of NA rows and B of NB.  The rows are
;; independent, so -P omp runs them on the threads.
(define (rbf-from-products g sa sb gamma na nb)
  (do ((i 0 (+ i 1))) ((= i na))
    (do ((j 0 (+ j 1))) ((= j nb))
      (let ((d (- (+ (vector-ref sa i) (vector-ref sb j))
                  (* 2.0 (vector-ref g (+ (* i nb) j))))))
        (vector-set! g (+ (* i nb) j)
                     (exp (* (- 0.0 gamma) (if (< d 0.0) 0.0 d)))))))
  0)

;;;; liblinear's solver for the linear epsilon-SVR with the L1 loss,
;;;; whole: solve_l2r_l1l2_svr (Ho and Lin 2012, Algorithm 4) for
;;;; L2R_L1LOSS_SVR_DUAL, the code scikit-learn's LinearSVR(loss=
;;;; "epsilon_insensitive", dual=True, fit_intercept=False) runs, written
;;;; out in the subset.
;;;;
;;;;   min_w  1/2 ||w||^2 + C sum_i max(0, |y_i - w.x_i| - EPSILON)
;;;;
;;;; by coordinate descent on the dual variables beta_i in [-C, C]
;;;; (w = sum beta_i x_i): each sweep visits the active part of the
;;;; index in a random order, steps beta_i to the minimizer of its
;;;; one-variable problem (a soft threshold at EPSILON around the
;;;; gradient, clipped to the box), and moves w along x_i.  A beta at 0
;;;; or at a bound whose gradient keeps it there by more than last
;;;; sweep's worst violation leaves the active part; when the summed
;;;; violation of a sweep falls below TOL times the first one's, the
;;;; active part is reopened to all points for a verifying sweep, and a
;;;; fit ends when that holds over all of them -- or after ITERS sweeps.
;;;;
;;;; X is n rows of p (x[i*p+j]).  W and BETA come back filled; XNORM
;;;; gets x_i . x_i.  Returns the sweep count.  The random numbers are
;;;; Park-Miller's minimal standard by Schrage's method, seeded by SEED.
;;;;

(define (svr-liblinear x y w beta xnorm cost epsilon iters tol seed n p)
  (let ((index (make-vector n 0))
        (rng seed)
        (active n)
        (gmaxold 1e300)
        (ginit -1.0)
        (iter 0)
        (done 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((acc 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                              (vector-ref x (+ (* i p) j))))))
        (vector-set! xnorm i acc))
      (vector-set! beta i 0.0)
      (vector-set! index i i))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! w j 0.0))
    (do () ((or (= done 1) (>= iter iters)))
      (let ((gmaxnew 0.0) (gnorm1new 0.0))
        ;; the random permutation of the active part
        (do ((t 0 (+ t 1))) ((= t active))
          (set! rng (- (* 16807 (remainder rng 127773)) (* 2836 (quotient rng 127773))))
          (if (< rng 0) (set! rng (+ rng 2147483647)) 0)
          (let ((k (+ t (remainder rng (- active t))))
                (tt (vector-ref index t)))
            (vector-set! index t (vector-ref index k))
            (vector-set! index k tt)))
        (let ((s 0))
          (do () ((>= s active))
            (let ((i (vector-ref index s)))
              (let ((g (- 0.0 (vector-ref y i)))
                    (h (vector-ref xnorm i))
                    (b (vector-ref beta i)))
                (do ((j 0 (+ j 1))) ((= j p))
                  (set! g (+ g (* (vector-ref x (+ (* i p) j)) (vector-ref w j)))))
                (let ((gp (+ g epsilon)) (gn (- g epsilon)) (viol 0.0) (shrunk 0))
                  ;; the violation, and shrinking (liblinear's three cases)
                  (if (= b 0.0)
                      (if (< gp 0.0)
                          (set! viol (- 0.0 gp))
                          (if (> gn 0.0)
                              (set! viol gn)
                              (if (and (> gp gmaxold) (< gn (- 0.0 gmaxold))) (set! shrunk 1) 0)))
                      (if (>= b cost)
                          (if (> gp 0.0)
                              (set! viol gp)
                              (if (< gp (- 0.0 gmaxold)) (set! shrunk 1) 0))
                          (if (<= b (- 0.0 cost))
                              (if (< gn 0.0)
                                  (set! viol (- 0.0 gn))
                                  (if (> gn gmaxold) (set! shrunk 1) 0))
                              (if (> b 0.0)
                                  (set! viol (if (< gp 0.0) (- 0.0 gp) gp))
                                  (set! viol (if (< gn 0.0) (- 0.0 gn) gn))))))
                  (if (= shrunk 1)
                      (begin
                        (set! active (- active 1))
                        (vector-set! index s (vector-ref index active))
                        (vector-set! index active i))
                      (begin
                        (if (> viol gmaxnew) (set! gmaxnew viol) 0)
                        (set! gnorm1new (+ gnorm1new viol))
                        ;; the Newton direction of the one-variable problem
                        (let ((d (if (< gp (* h b)) (/ (- 0.0 gp) h)
                                     (if (> gn (* h b)) (/ (- 0.0 gn) h) (- 0.0 b)))))
                          (if (or (> d 1e-12) (< d -1e-12))
                              (let ((bn (+ b d)))
                                (let ((bc (if (< bn (- 0.0 cost)) (- 0.0 cost) (if (> bn cost) cost bn))))
                                  (vector-set! beta i bc)
                                  (if (not (= bc b))
                                      (do ((j 0 (+ j 1))) ((= j p))
                                        (vector-set! w j (+ (vector-ref w j)
                                                            (* (- bc b) (vector-ref x (+ (* i p) j))))))
                                      #f)))
                              0))
                        (set! s (+ s 1)))))))))
        (if (= iter 0) (set! ginit gnorm1new) 0)
        (set! iter (+ iter 1))
        (if (<= gnorm1new (* tol ginit))
            (if (= active n)
                (set! done 1)
                (begin
                  (set! active n)
                  (set! gmaxold 1e300)))
            (set! gmaxold gmaxnew))))
    iter))

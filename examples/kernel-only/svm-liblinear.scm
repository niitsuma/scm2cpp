;;;; liblinear's solver for the L1-loss linear SVM, whole:
;;;; solve_l2r_l1l2_svc (Hsieh et al. 2008, Algorithm 3), the code
;;;; scikit-learn's LinearSVC(loss="hinge", dual=True,
;;;; fit_intercept=False) runs, written out in the subset.  Next to
;;;; svm-kernel.scm's sweep it has the two things liblinear relies on:
;;;;
;;;;   random order  the active part of the index is permuted at the
;;;;                 head of every sweep;
;;;;   shrinking     a point at a bound whose gradient points out of the
;;;;                 box by more than last sweep's worst violation leaves
;;;;                 the active part (swapped past its end), so late
;;;;                 sweeps touch only the few points still moving; when
;;;;                 the active part has converged (max PG - min PG <=
;;;;                 TOL) everything is re-activated for one verifying
;;;;                 sweep, and only a sweep over all points ends the fit.
;;;;
;;;; The two go together: with a fixed order the same points are
;;;; shrunk sweep after sweep, and the fit stalls short of the optimum.
;;;; The random numbers are Park-Miller's minimal standard by Schrage's
;;;; method (all in 32-bit int), seeded by SEED, not liblinear's rand():
;;;; the order differs draw by draw, the distribution is the same.
;;;; Returns the number of sweeps.  The plain translation of this file
;;;; is the "liblinear in Scheme" row of the README's SVM table.
;;;;
;;;; --derive leaves it alone: the point a step works on is
;;;; i = index[s], a let-bound index, not a loop coordinate, so no memo
;;;; over the points can be indexed by it.
;;;;

(define (svm-liblinear x y w alpha xnorm cost iters tol seed n p)
  (with-arrays ((x (n p)) (y (n)) (w (p)) (alpha (n)) (xnorm (n)))
  (do ((i 0 (+ i 1))) ((= i n))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                            (vector-ref x (+ (* i p) j))))))
      (vector-set! xnorm i acc)))
  (let ((index (make-vector n 0))
        (rng seed)
        (active n)
        (pgmaxold 1e300) (pgminold -1e300)
        (stop 0) (sweeps 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! index i i))
    (do ((sweep 0 (+ sweep 1)))
        ((or (= sweep iters) (= stop 1)))
      (let ((pgmax -1e300) (pgmin 1e300))
        ;; the random permutation of the active part
        (do ((i 0 (+ i 1))) ((= i active))
          (set! rng (- (* 16807 (remainder rng 127773)) (* 2836 (quotient rng 127773))))
          (if (< rng 0) (set! rng (+ rng 2147483647)) 0)
          (let ((j (+ i (remainder rng (- active i))))
                (t (vector-ref index i)))
            (vector-set! index i (vector-ref index j))
            (vector-set! index j t)))
        (let ((s 0))
          (do () ((>= s active))
            (let ((i (vector-ref index s)))
              (let ((dot 0.0)
                    (old (vector-ref alpha i)))
                (do ((j 0 (+ j 1)))
                    ((= j p))
                  (set! dot (+ dot (* (vector-ref x (+ (* i p) j))
                                      (vector-ref w j)))))
                (let ((g (- (* (vector-ref y i) dot) 1.0))
                      (pg 0.0)
                      (shrunk 0))
                  (if (= old 0.0)
                      (if (> g pgmaxold) (set! shrunk 1) (if (< g 0.0) (set! pg g) 0))
                      (if (= old cost)
                          (if (< g pgminold) (set! shrunk 1) (if (> g 0.0) (set! pg g) 0))
                          (set! pg g)))
                  (if (= shrunk 1)
                      ;; out of the active part: swap with its last
                      ;; entry and look at position s again
                      (begin
                        (set! active (- active 1))
                        (vector-set! index s (vector-ref index active))
                        (vector-set! index active i))
                      (begin
                        (if (> pg pgmax) (set! pgmax pg) 0)
                        (if (< pg pgmin) (set! pgmin pg) 0)
                        (if (or (> pg 1e-12) (< pg -1e-12))
                            (let ((step (- old (/ g (vector-ref xnorm i)))))
                              (let ((anew (if (< step 0.0) 0.0 (if (> step cost) cost step))))
                                (vector-set! alpha i anew)
                                (do ((j 0 (+ j 1)))
                                    ((= j p))
                                  (vector-set! w j
                                               (+ (vector-ref w j)
                                                  (* (vector-ref x (+ (* i p) j))
                                                     (* (- anew old) (vector-ref y i))))))))
                            0)
                        (set! s (+ s 1)))))))))
        (set! sweeps (+ sweeps 1))
        (if (<= (- pgmax pgmin) tol)
            (if (= active n)
                (set! stop 1)
                (begin
                  (set! active n)
                  (set! pgmaxold 1e300)
                  (set! pgminold -1e300)))
            (begin
              (set! pgmaxold (if (<= pgmax 0.0) 1e300 pgmax))
              (set! pgminold (if (>= pgmin 0.0) -1e300 pgmin))))))
    sweeps)))

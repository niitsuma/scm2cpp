;;;; A linear support vector machine by dual coordinate descent, in
;;;; primal form: the algorithm of liblinear (Hsieh et al. 2008) for the
;;;; L1-loss SVM, written as flat loops over X as numpy holds it, n
;;;; rows of p, x[i*p+j], with no kernel matrix anywhere in it.
;;;;
;;;;   min_w  1/2 ||w||^2 + C sum_i max(0, 1 - y_i w.x_i)
;;;;
;;;; The dual variables alpha_i in [0, C] are swept in order; for each
;;;; the gradient g = y_i (w . x_i) - 1 is read off the primal vector,
;;;; alpha_i moves to the clipped Newton step, and w moves by the
;;;; change times y_i x_i.  W is the working state -- the scratch the
;;;; derivation finds: updated by a scaled row of X, read only in dot
;;;; products against rows of X -- so --derive replaces it by the memo
;;;; c_i = x_i . w over the kernel matrix K = X X' it hoists: the
;;;; kernel-form solver, which a nonlinear SVM runs on any K.  That form
;;;; pays when there are fewer observations than features, and the
;;;; derivation says so: the derived body runs under (if (< n p) ..).
;;;;
;;;; XNORM holds x_i . x_i (the diagonal Q_ii), computed here; TOL ends a
;;;; fit as liblinear's does, when the projected gradients of a sweep
;;;; span no more than it (max PG - min PG <= TOL); ITERS bounds the
;;;; sweeps.  No shrinking, no random order: the deterministic sweep is
;;;; what the derivation and the oracle compare.  svm-liblinear.scm is
;;;; liblinear's solver whole, with both.
;;;;

(define (svm x y w alpha xnorm cost iters tol n p)
  ;; The shapes, for --derive: X is n rows of p, the rest vectors.
  (with-arrays ((x (n p)) (y (n)) (w (p)) (alpha (n)) (xnorm (n)))
  ;; Q_ii = x_i . x_i
  (do ((i 0 (+ i 1))) ((= i n))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                            (vector-ref x (+ (* i p) j))))))
      (vector-set! xnorm i acc)))
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1)))
        ((or (= sweep iters) (= stop 1)))
      (let ((pgmax -1e300) (pgmin 1e300))
        (do ((i 0 (+ i 1)))
            ((= i n))
          ;; g = y_i (w . x_i) - 1: the dot product walks row i of X,
          ;; the loop --derive replaces by a read of the memo c[i]
          (let ((dot 0.0)
                (old (vector-ref alpha i)))
            (do ((j 0 (+ j 1)))
                ((= j p))
              (set! dot (+ dot (* (vector-ref x (+ (* i p) j))
                                  (vector-ref w j)))))
            (let ((g (- (* (vector-ref y i) dot) 1.0))
                  (pg 0.0))
              ;; the projected gradient: g, except at a bound that g
              ;; pushes against, where it is 0
              (if (= old 0.0)
                  (if (< g 0.0) (set! pg g) 0)
                  (if (= old cost)
                      (if (> g 0.0) (set! pg g) 0)
                      (set! pg g)))
              (if (> pg pgmax) (set! pgmax pg) 0)
              (if (< pg pgmin) (set! pgmin pg) 0)
              ;; the clipped Newton step, alpha_i in [0, C]
              (let ((step (- old (/ g (vector-ref xnorm i)))))
                (let ((anew (if (< step 0.0) 0.0 (if (> step cost) cost step))))
                  (vector-set! alpha i anew)
                  ;; an alpha that did not move leaves w as it is; one
                  ;; that did moves w by (anew - old) y_i x_i, along row i
                  ;; again -- the update --derive turns into c += (anew -
                  ;; old) y_i K[:,i], O(n) instead of O(p)
                  (if (not (= anew old))
                      (do ((j 0 (+ j 1)))
                          ((= j p))
                        (vector-set! w j
                                     (+ (vector-ref w j)
                                        (* (vector-ref x (+ (* i p) j))
                                           (* (- anew old) (vector-ref y i))))))
                      #f))))))
        (if (<= (- pgmax pgmin) tol) (set! stop 1) 0))))
  0))

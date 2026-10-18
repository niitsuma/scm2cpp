;;;; The lasso path from the design matrix as numpy holds it: X is n
;;;; rows of p, x[i*p+j], C order, and nothing is prepared outside.
;;;; The kernel copies y into the residual and takes the column norms
;;;; itself, then runs the residual-form coordinate descent of
;;;; lasso-kernel.scm down the columns.  This is the kernel behind
;;;; DerivedLasso in python/scm2cpp-lasso: with --derive the memo
;;;; c = X'r, the Gram X'X (one dsyrk under --blas) and the
;;;; (if (< p n) ..) guard are the translator's, and the Python side
;;;; hands over X and y as they are -- no transposed copy, no norms.
;;;;
;;;; RESID and XNORM are parameters only so that the caller owns the
;;;; buffers (the -M wrapper takes numpy arrays); they are filled here.
;;;; The rest -- LAMS, BETAS, ITERS, TOL -- is as in lasso-kernel.scm.
;;;;

(include "soft-threshold.scm")

;; x       the design, n rows of p (x[i*p+j]); read only
;; y       the observations, n
;; resid   the residual r = y - X beta, n; filled from y here, kept current
;; xnorm   the squared column norms, p; filled here
;; beta    the coefficients, p; the working state, warm-started along the path
;; lams    the penalties, largest first, nlam of them
;; betas   row l = the fit at lams[l], flat nlam x p
;; iters   at most this many sweeps per penalty
;; tol     a sweep whose largest coefficient move is <= tol ends the fit
;;         (0.0: the exact fixed point, a sweep that moved nothing)
(define (lasso-design x y resid xnorm beta lams betas iters tol n p nlam)
  ;; The shapes, for --derive: X is n rows of p, the rest are vectors or
  ;; the nlam x p table.  The declaration changes nothing in the plain
  ;; translation; it is what lets the derivation read x[i*p+j] as a
  ;; column of X.
  (with-arrays ((x (n p)) (y (n)) (resid (n)) (xnorm (p)) (beta (p))
                (lams (nlam)) (betas (nlam p)))
  ;; r = y: nothing has been fitted yet
  (do ((i 0 (+ i 1))) ((= i n))
    (vector-set! resid i (vector-ref y i)))
  ;; xnorm[j] = sum_i x[i,j]^2: the denominator of every coordinate
  ;; step.  Under --derive this fill is folded into the diagonal of the
  ;; Gram matrix (the merge rule) and no longer runs in the Gram branch.
  (do ((j 0 (+ j 1))) ((= j p))
    (let ((acc 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                            (vector-ref x (+ (* i p) j))))))
      (vector-set! xnorm j acc)))
  ;; The path: one fit per penalty, each warm-started from the last.
  (do ((l 0 (+ l 1)))
      ((= l nlam))
    (let ((lam (vector-ref lams l)))
      (let ((stop 0))
        ;; Sweeps over the coordinates until none moved by more than tol,
        ;; or iters of them.
        (do ((sweep 0 (+ sweep 1)))
            ((or (= sweep iters) (= stop 1)))
          (let ((maxmove 0.0))
            (do ((j 0 (+ j 1)))
                ((= j p))
              ;; rho = x_j . r + xnorm[j] beta[j]: the unpenalized optimum
              ;; of coordinate j with the others held, times xnorm[j].
              ;; The dot product walks column j of X -- the loop --derive
              ;; replaces by a read of the memo c[j].
              (let ((rho 0.0)
                    (old (vector-ref beta j)))
                (do ((i 0 (+ i 1)))
                    ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                      (vector-ref resid i)))))
                (set! rho (+ rho (* old (vector-ref xnorm j))))
                ;; Soft-threshold at lam * n (the objective is scaled by
                ;; 1/(2n), as scikit-learn's), then divide by the norm:
                ;; the new value of coordinate j.
                (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                               (vector-ref xnorm j))))
                  (vector-set! beta j bnew)
                  ;; A coordinate that did not move leaves the residual
                  ;; as it is (most coordinates of a sparse solution);
                  ;; one that did moves r by -(bnew - old) x_j, down
                  ;; column j again.  --derive turns this update into
                  ;; c -= (bnew - old) G[:,j], O(p) instead of O(n).
                  ;; maxmove is |bnew - old| at its largest, kept with
                  ;; two comparisons (no abs or max in the subset).
                  (if (not (= bnew old))
                      (begin
                        (if (> (- bnew old) maxmove) (set! maxmove (- bnew old)) 0)
                        (if (> (- old bnew) maxmove) (set! maxmove (- old bnew)) 0)
                        (do ((i 0 (+ i 1)))
                            ((= i n))
                          (vector-set! resid i
                                       (- (vector-ref resid i)
                                          (* (vector-ref x (+ (* i p) j))
                                             (- bnew old))))))
                      #f))))
            (if (<= maxmove tol) (set! stop 1) 0))))
      ;; Row l of betas gets the fit at this penalty; beta carries on to
      ;; the next one as its warm start.
      (do ((j 0 (+ j 1)))
          ((= j p))
        (vector-set! betas (+ (* l p) j) (vector-ref beta j))))))
  0)

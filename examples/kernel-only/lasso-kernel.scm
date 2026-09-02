;; A kernel with no main: lasso coordinate descent, meant to be called
;; from elsewhere rather than run on its own. Nothing here says how long
;; the arrays are, so inference gives them std::vector<double> -- an
;; extent it does not have to know -- and -M can expose them across the
;; C ABI as a pointer and a length. A program that does call it with
;; fixed-size arrays gets boost::array parameters instead.
;;;; LASSO regression by coordinate descent, along a path of penalties.
;;;; The design matrix is column major and flat, indexed j*n+i, because a
;;;; sweep touches one column at a time.  RESID is y - X beta, kept current.
;;;;
;;;; LAMS holds the penalties, NLAM of them, and the fit at each is warm-
;;;; started from the one before -- BETA and RESID are the working state
;;;; and carry over -- with the coefficients at penalty l stored in row l
;;;; of BETAS (flat, l*p+j).  A single fit is the path of length one: pass
;;;; LAMS of one element and BETAS of p cells.  Writing the path into the
;;;; kernel rather than around it in Python is what lets the rewrites see
;;;; it: the Gram matrix the covariance rule introduces is the same for
;;;; every penalty, and the loop-invariant hoist then builds it once.
;;;;
;;;; Two things are written the way they are to suit the translator.  BNEW is
;;;; not called NEW because that is a C++ keyword and the generated identifier
;;;; is not escaped.  The penalty is multiplied by (* 1.0 n) rather than by N
;;;; so that inference is forced to give LAM a floating type; with N alone the
;;;; only constraint on LAM is an integer multiplication.

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

(define (lasso x beta resid xnorm lams betas iters n p nlam)
  (do ((l 0 (+ l 1)))
      ((= l nlam))
    (let ((lam (vector-ref lams l)))
      (do ((sweep 0 (+ sweep 1)))
          ((= sweep iters))
        (do ((j 0 (+ j 1)))
            ((= j p))
          (let ((rho 0.0)
                (old (vector-ref beta j)))
            (do ((i 0 (+ i 1)))
                ((= i n))
              (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                  (vector-ref resid i)))))
            (set! rho (+ rho (* old (vector-ref xnorm j))))
            (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                           (vector-ref xnorm j))))
              (vector-set! beta j bnew)
              ;; a coordinate that did not move leaves the residual as it
              ;; is; most coordinates of a sparse solution are such, so this
              ;; halves the passes over X, as scikit-learn's descent does
              (if (not (= bnew old))
                  (do ((i 0 (+ i 1)))
                      ((= i n))
                    (vector-set! resid i
                                 (- (vector-ref resid i)
                                    (* (vector-ref x (+ (* j n) i)) (- bnew old)))))
                  #f)))))
      (do ((j 0 (+ j 1)))
          ((= j p))
        (vector-set! betas (+ (* l p) j) (vector-ref beta j)))))
  0)

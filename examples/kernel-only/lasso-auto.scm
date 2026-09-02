;; The lasso path with the choice scikit-learn's precompute='auto'
;; makes, written by hand: when there are more observations than
;; features the Gram matrix is built once and the sweeps run over it
;; (cov-descend of lasso-cov.scm, the covariance route); otherwise the
;; residual is carried and every coordinate reads its column of X
;; (lasso of lasso-kernel.scm, the residual route).  Both routes are
;; taken by include, so this file adds the choice and the Gram
;; preparation and nothing else.
;;
;; The Gram route is the same arithmetic --derive writes into
;; lasso-kernel.scm's kernel (lasso-kernel.expanded.scm): G = X X^T
;; and c = X r once in front of the path, c carried across the warm
;; starts, the residual brought current at the end from the
;; coefficients' total movement.  The products are written as the
;; array algebra's matmul forms, so --blas / --cublas replace each by
;; one BLAS call (rewrite-blas.scm) and the plain translation expands
;; them to loops.  This file is meant to be translated WITHOUT
;; --derive: the derivation would turn the residual route into the
;; Gram route as well, and the whole point of the choice is to keep
;; the residual route where n <= p, where the O(n p^2) Gram build is
;; not paid for by the O(p^2) sweeps it buys.
;;
;; Same signature as lasso: X is p rows of n (column j of the design
;; is row j here, j*n+i), RESID is y - X beta kept current on the way
;; in and on the way out, LAMS the NLAM penalties, row l of BETAS the
;; fit at penalty l.  The choice is n > p, as scikit-learn's
;; lasso_path makes it when precompute is 'auto'.

(include "lasso-kernel.scm")
(include "lasso-cov.scm")

(define (lasso-auto x beta resid xnorm lams betas iters n p nlam)
  (with-arrays ((x (p n)) (resid (n)) (beta (p)) (xnorm (p))
                (lams (nlam)) (betas (nlam p)))
    (if (> n p)
        (let ((g (make-vector (* p p) 0.0))
              (c (make-vector p 0.0))
              (b0 (make-vector p 0.0)))
          (with-arrays ((g (p p)) (c (p)) (b0 (p)))
            (array-set! g (matmul x (transpose x)))
            (array-set! c (matmul x resid))
            (array-set! b0 beta)
            (do ((l 0 (+ l 1)))
                ((= l nlam))
              (cov-descend g c beta (vector-ref lams l) iters n p)
              (do ((j 0 (+ j 1)))
                  ((= j p))
                (vector-set! betas (+ (* l p) j) (vector-ref beta j))))
            (array-dec! resid (matmul (transpose x) (- beta b0)))))
        (lasso x beta resid xnorm lams betas iters n p nlam)))
  0)

;;;; Factor analysis over the covariance: scikit-learn's FactorAnalysis,
;;;; whose every iteration is an SVD of the n x p matrix
;;;; Xc / (sqrt(psi) sqrt(n)), taken instead from the p x p covariance
;;;; C = Xc'Xc / n formed once (a dsyrk under --blas).
;;;;
;;;; With D = diag(sqrt psi), that matrix's squared singular values and
;;;; right singular vectors are the eigenvalues and eigenvectors of
;;;; M = D^-1 C D^-1, and the variance it leaves out is trace M less the
;;;; top k eigenvalues.  So each iteration is M, its top k eigenpairs
;;;; (sym-eigen-top, LAPACK's dsyevr under --blas), and then scikit-
;;;; learn's own steps: W = sqrt(max(s - 1, 0)) V' D, the log-likelihood,
;;;; and psi = max(var - colsum W^2, 1e-12).  No pass over the rows.
;;;; The eigenproblem is exact: what scikit-learn's svd_method="lapack"
;;;; computes, where its default "randomized" approximates it.
;;;;

(include "sym-eigen.scm")

;; C (p x p) the covariance and VAR its diagonal; PSI (p) the starting
;; noise variances, left with the final ones; W (k x p) gets the
;; components, LL (maxit) the log-likelihood of each iteration.  N the
;; rows, K the components.  Returns the iterations taken, or maxit + 1
;; when the log-likelihood never rose by less than TOL (scikit-learn's
;; ConvergenceWarning; psi then holds one more update, as there).
(define (fa-fit c var psi w ll n p k maxit tol)
  (let ((m (make-vector (* p p) 0.0))
        (v (make-vector (* p k) 0.0))
        (ev (make-vector k 0.0))
        (e (make-vector p 0.0))
        (sp (make-vector p 0.0))
        (llconst (+ (* 1.8378770664093453 (exact->inexact p)) (exact->inexact k)))
        (it 0)
        (done 0)
        (old -1e300))
    (do ((i 0 (+ i 1))) ((= i maxit))
      (if (= done 0)
          (let ((tr 0.0) (sumlog 0.0) (sums 0.0) (slp 0.0))
            (do ((j 0 (+ j 1))) ((= j p))
              (vector-set! sp j (+ (sqrt (vector-ref psi j)) 1e-12)))
            (do ((a 0 (+ a 1))) ((= a p))
              (do ((b 0 (+ b 1))) ((= b p))
                (vector-set! m (+ (* a p) b)
                             (/ (vector-ref c (+ (* a p) b)) (* (vector-ref sp a) (vector-ref sp b))))))
            (do ((j 0 (+ j 1))) ((= j p))
              (set! tr (+ tr (vector-ref m (+ (* j p) j)))))
            (sym-eigen-top m v ev e p k)
            (do ((r 0 (+ r 1))) ((= r k))
              (set! sumlog (+ sumlog (log (vector-ref ev r))))
              (set! sums (+ sums (vector-ref ev r)))
              (let ((f (sqrt (max (- (vector-ref ev r) 1.0) 0.0))))
                (do ((j 0 (+ j 1))) ((= j p))
                  (vector-set! w (+ (* r p) j) (* (* f (vector-ref v (+ (* j k) r))) (vector-ref sp j))))))
            (do ((j 0 (+ j 1))) ((= j p))
              (set! slp (+ slp (log (vector-ref psi j)))))
            (let ((l (* (* -0.5 (* 1.0 n)) (+ (+ llconst sumlog) (+ (- tr sums) slp)))))
              (vector-set! ll i l)
              (set! it (+ i 1))
              (if (< (- l old) tol)
                  (set! done 1)
                  (begin
                    (set! old l)
                    (do ((j 0 (+ j 1))) ((= j p))
                      (let ((acc 0.0))
                        (do ((r 0 (+ r 1))) ((= r k))
                          (set! acc (+ acc (* (vector-ref w (+ (* r p) j)) (vector-ref w (+ (* r p) j))))))
                        (vector-set! psi j (max (- (vector-ref var j) acc) 1e-12))))))))
          0))
    (if (= done 1) it (+ maxit 1))))

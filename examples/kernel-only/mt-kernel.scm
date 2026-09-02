;;;; The multi-task lasso in residual form.  W is p x ntask flat
;;;; (row j = feature j), RESID is ntask x n flat (row t = task t), X
;;;; is column-major as in lasso-kernel.scm.  A feature's row of W
;;;; enters or leaves for every task at once, under the L2 norm of
;;;; the row's unpenalized optimum z, z[t] = x_j . r_t + xnorm[j] w[j,t]:
;;;; the row moves to z * max(0, ||z|| - lam1 n) / (||z|| (xnorm[j] + lam2 n)).
;;;;
;;;; This is the form before the covariance update was written by hand
;;;; into mt-descend of lasso-cov.scm; z is computed twice, once for
;;;; the norm and once per task for the step, as mt-descend computes
;;;; c + gjj*old twice.

(define (mt x w resid xnorm lam1 lam2 iters n p ntask)
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1))) ((or (= sweep iters) (= stop 1)))
      (let ((moved 0))
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((gjj (vector-ref xnorm j))
                (nrm2 0.0))
            (do ((t 0 (+ t 1))) ((= t ntask))
              (let ((rho 0.0))
                (do ((i 0 (+ i 1))) ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                      (vector-ref resid (+ (* t n) i))))))
                (let ((z (+ rho (* gjj (vector-ref w (+ (* j ntask) t))))))
                  (set! nrm2 (+ nrm2 (* z z))))))
            (let ((nrm (sqrt nrm2))
                  (thr (* lam1 (* 1.0 n))))
              (let ((scale (if (> nrm thr)
                               (/ (- nrm thr)
                                  (* nrm (+ gjj (* lam2 (* 1.0 n)))))
                               0.0)))
                (do ((t 0 (+ t 1))) ((= t ntask))
                  (let ((old (vector-ref w (+ (* j ntask) t)))
                        (rho 0.0))
                    (do ((i 0 (+ i 1))) ((= i n))
                      (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                          (vector-ref resid (+ (* t n) i))))))
                    (let ((wnew (* scale (+ rho (* gjj old)))))
                      (vector-set! w (+ (* j ntask) t) wnew)
                      (if (not (= wnew old))
                          (begin
                            (set! moved 1)
                            (do ((i 0 (+ i 1))) ((= i n))
                              (vector-set! resid (+ (* t n) i)
                                           (- (vector-ref resid (+ (* t n) i))
                                              (* (vector-ref x (+ (* j n) i))
                                                 (- wnew old))))))
                          #f))))))))
        (if (= moved 0) (set! stop 1) 0))))
  0)

;; The multi-task kernel of derive-mt.scm with every matrix stored the
;; numpy way: X n rows of p (x[i*p+j]), the residual n rows of ntask
;; (resid[i*ntask+t]), W p rows of ntask as before.  A task's residual
;; is then a column, updated down its length, resid[i,t] -= x[i,j] d,
;; and read in dot products against columns of X.  --derive must raise
;; those to (col-dec! resid t (scale d (col x j))) and
;; (array-sum (* (col x j) (col resid t))), difference them as it
;; differences the row-stored kernel -- the memo C = R'X (ntask by p),
;; the Gram X'X, the restoration R -= X (W - W0) -- and guard the
;; result by the (n p) declaration.  Same dyadic data as derive-mt.scm,
;; transposed in memory: W prints the same digits, the residual its
;; transpose.
(include "../examples/kernel-only/soft-threshold.scm")

(define (mt-col x w resid xnorm lam1 lam2 iters n p ntask)
  (with-arrays ((x (n p)) (w (p ntask)) (resid (n ntask)) (xnorm (p)))
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1))) ((or (= sweep iters) (= stop 1)))
      (let ((moved 0))
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((gjj (vector-ref xnorm j))
                (nrm2 0.0))
            (do ((t 0 (+ t 1))) ((= t ntask))
              (let ((rho 0.0))
                (do ((i 0 (+ i 1))) ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                      (vector-ref resid (+ (* i ntask) t))))))
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
                      (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                          (vector-ref resid (+ (* i ntask) t))))))
                    (let ((wnew (* scale (+ rho (* gjj old)))))
                      (vector-set! w (+ (* j ntask) t) wnew)
                      (if (not (= wnew old))
                          (begin
                            (set! moved 1)
                            (do ((i 0 (+ i 1))) ((= i n))
                              (vector-set! resid (+ (* i ntask) t)
                                           (- (vector-ref resid (+ (* i ntask) t))
                                              (* (vector-ref x (+ (* i p) j))
                                                 (- wnew old))))))
                          #f))))))))
        (if (= moved 0) (set! stop 1) 0)))))
  0)

(define (main)
  (let ((n 4) (p 3) (ntask 2)
        ;; derive-mt.scm's x (3 rows of 4) as 4 rows of 3
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5))
        ;; and its y (2 rows of 4) as 4 rows of 2
        (y (vector 1.0 0.5
                   -1.0 1.0
                   2.0 -1.0
                   0.5 2.0))
        (w (make-vector 6 0.0))
        (resid (make-vector 8 0.0))
        (xnorm (make-vector 3 0.0)))
    (do ((i 0 (+ i 1))) ((= i (* ntask n)))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                              (vector-ref x (+ (* i p) j))))))
        (vector-set! xnorm j acc)))
    (mt-col x w resid xnorm 0.0625 0.125 20 n p ntask)
    (do ((k 0 (+ k 1))) ((= k (* p ntask)))
      (display (vector-ref w k)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i (* ntask n)))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

;; The lasso kernel of derive-lasso.scm with the design stored the other
;; way round: n rows of p, x[i*p+j], numpy's C order, declared (x (n p)).
;; A sweep then walks a column of x -- rho = sum_i x[i,j] r[i], r[i] -=
;; x[i,j] (bnew - old) -- and --derive must read those as (col x j),
;; difference them exactly as it differences the row-walking kernel
;; (memo c = X'r, Gram X'X, restore r -= X d, the transposes on the
;; other side), and put the result under the same (if (< p n) ..)
;; guard with p and n read off the (n p) declaration.  Same dyadic data
;; as derive-lasso.scm, transposed, so the coefficients and the
;; residual print the same digits.
(include "../examples/kernel-only/soft-threshold.scm")

(define (lasso-col x beta resid xnorm lams betas iters tol n p nlam)
  (with-arrays ((x (n p)) (resid (n)) (beta (p)) (xnorm (p))
                (lams (nlam)) (betas (nlam p)))
  (do ((l 0 (+ l 1)))
      ((= l nlam))
    (let ((lam (vector-ref lams l)))
      (let ((stop 0))
        (do ((sweep 0 (+ sweep 1)))
            ((or (= sweep iters) (= stop 1)))
          (let ((maxmove 0.0))
            (do ((j 0 (+ j 1)))
                ((= j p))
              (let ((rho 0.0)
                    (old (vector-ref beta j)))
                (do ((i 0 (+ i 1)))
                    ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                      (vector-ref resid i)))))
                (set! rho (+ rho (* old (vector-ref xnorm j))))
                (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                               (vector-ref xnorm j))))
                  (vector-set! beta j bnew)
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
      (do ((j 0 (+ j 1)))
          ((= j p))
        (vector-set! betas (+ (* l p) j) (vector-ref beta j))))))
  0)

(define (main)
  (let ((n 4) (p 3) (nlam 2)
        ;; derive-lasso.scm's x, 3 rows of 4, written as 4 rows of 3
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5))
        (y (vector 1.0 -1.0 2.0 0.5))
        (beta (make-vector 3 0.0))
        (resid (make-vector 4 0.0))
        (xnorm (make-vector 3 0.0))
        (lams (vector 0.25 0.0625))
        (betas (make-vector 6 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                              (vector-ref x (+ (* i p) j))))))
        (vector-set! xnorm j acc)))
    (lasso-col x beta resid xnorm lams betas 20 0.0 n p nlam)
    (do ((t 0 (+ t 1))) ((= t 6))
      (display (vector-ref betas t)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

;; quantile.scm on fourteen rows of two features: the median and the
;; 0.8 quantile fits (the design with the intercept's column in front),
;; the 0.4 quantile fit with an L1 penalty as two more rows, which
;; holds the second coefficient at zero, and a design with a zero
;; column, whose Gram matrix the Cholesky refuses (status 2).  Each
;; fit prints its status, the coefficients, the sum of the check losses
;; at them and how many rows the dual solution leaves strictly inside
;; (0, 1): the rows the fit passes through, as many as there are
;; columns.  The weighted Gram matrices are loops plain, dsyrk and
;; dposv under --blas.  Then lu-solve, the vertex's square solve: a
;; system whose first pivot is zero, and a singular one (1).
(include "../examples/kernel-only/quantile.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

;; A (n x m), YY (n), the quantile TAU of the first N0 rows (the rest,
;; the penalty's, sit at 1/2)
(define (run a yy tau n0 n m)
  (let ((c (make-vector n 0.0)) (x (make-vector n 0.0))
        (coef (make-vector m 0.0)) (out (make-vector 3 0.0))
        (loss 0.0) (inside 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! c i (- 0.0 (vector-ref yy i)))
      (vector-set! x i (if (< i n0) (- 1.0 tau) 0.5)))
    (quantile-fn a c x coef out 1e-12 100 n m)
    (display (vector-ref out 2)) (newline)
    (if (= (vector-ref out 2) 0.0)
        (begin
          (show coef m)
          (do ((i 0 (+ i 1))) ((= i n))
            (let ((r (vector-ref yy i)) (ti (if (< i n0) tau 0.5)))
              (do ((j 0 (+ j 1))) ((= j m))
                (set! r (- r (* (vector-ref a (+ (* i m) j)) (vector-ref coef j)))))
              (set! loss (+ loss (if (< r 0.0) (* (- ti 1.0) r) (* ti r))))
              (if (and (> (vector-ref x i) 1e-6) (< (vector-ref x i) (- 1.0 1e-6)))
                  (set! inside (+ inside 1))
                  0)))
          (display loss) (newline)
          (display inside) (newline))
        0)
    0))

;; L (3 x 3 by rows) x = V: the status, then x
(define (solve3 l0 v0)
  (let ((l (make-vector 9 0.0)) (v (make-vector 3 0.0)))
    (do ((i 0 (+ i 1))) ((= i 9)) (vector-set! l i (vector-ref l0 i)))
    (do ((i 0 (+ i 1))) ((= i 3)) (vector-set! v i (vector-ref v0 i)))
    (let ((bad (lu-solve l v 3)))
      (display bad) (newline)
      (if (= bad 0) (show v 3) 0)
      0)))

(define (main)
  (let ((x0 (vector 0.31 -0.72  1.05 0.18  -0.44 0.93  0.67 -1.21  -0.09 0.52
                    1.38 -0.35  -0.81 -0.27  0.44 1.12  0.05 -0.63  -0.38 0.91
                    0.27 0.74  -0.16 1.41  -1.02 0.58  -0.47 0.29))
        (y0 (vector 0.83 1.94 -0.37 2.61 0.12 2.05 -1.48 0.71 1.33 -0.92
                    0.46 -0.58 -2.07 3.4))
        (n 14) (p 2) (lam 2.9))
    (let ((a (make-vector (* n 3) 0.0)) (ap (make-vector (* (+ n p) 3) 0.0))
          (az (make-vector (* n 3) 0.0))
          (y (make-vector n 0.0)) (yp (make-vector (+ n p) 0.0)))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! a (* i 3) 1.0)
        (vector-set! ap (* i 3) 1.0)
        (vector-set! az (* i 3) 1.0)
        (vector-set! y i (vector-ref y0 i))
        (vector-set! yp i (vector-ref y0 i))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! a (+ (* i 3) (+ j 1)) (vector-ref x0 (+ (* i p) j)))
          (vector-set! ap (+ (* i 3) (+ j 1)) (vector-ref x0 (+ (* i p) j)))))
      ;; the zero column: az keeps column 1 and leaves column 2 at zero
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! az (+ (* i 3) 1) (vector-ref x0 (* i p))))
      ;; the penalty lam (|b1| + |b2|) as the rows 2 lam e_j with response 0
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! ap (+ (* (+ n j) 3) (+ j 1)) (* 2.0 lam)))
      (run a y 0.5 n n 3)
      (run a y 0.8 n n 3)
      (run ap yp 0.4 n (+ n p) 3)
      (run az y 0.5 n n 3)
      (solve3 (vector 0.0 2.0 1.0  1.0 1.0 1.0  2.0 1.0 -1.0) (vector 7.0 6.0 1.0))
      (solve3 (vector 1.0 2.0 3.0  2.0 4.0 6.0  1.0 0.0 1.0) (vector 1.0 2.0 3.0))
      0)))

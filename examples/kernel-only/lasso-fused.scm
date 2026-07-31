;; Lasso over moving-average features, without ever forming the design
;; matrix. Column j of X is the moving average of the base sequence at
;; window j+1, so X[row][j] = (ps[t] - ps[t-w]) / w with t = wmax+row: the
;; prefix sums ps and the window length determine it, and an element can
;; be recomputed whenever it is needed. The solver therefore reads n
;; numbers where the ordinary form reads n*p.

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

;; The element X[row][j] that the ordinary form would have stored. The
;; reciprocal of the window is passed in rather than dividing here: a
;; division per element costs more than the memory the fusion saves, and
;; 1/w is the same for the whole column.
(define (ma-elem ps wmax row w invw)
  (let ((t (+ wmax row)))
    (* (- (vector-ref ps t) (vector-ref ps (- t w))) invw)))

(define (lasso-fused ps beta resid xnorm lam iters nobs p wmax)
  (do ((sweep 0 (+ sweep 1)))
      ((= sweep iters))
    (do ((j 0 (+ j 1)))
        ((= j p))
      (let ((w (+ j 1))
            (invw (/ 1.0 (+ j 1)))
            (rho 0.0)
            (old (vector-ref beta j)))
        (do ((row 0 (+ row 1)))
            ((= row nobs))
          (set! rho (+ rho (* (* (- (vector-ref ps (+ wmax row)) (vector-ref ps (- (+ wmax row) w))) invw)
                              (vector-ref resid row)))))
        (set! rho (+ rho (* old (vector-ref xnorm j))))
        (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 nobs)))
                       (vector-ref xnorm j))))
          (vector-set! beta j bnew)
          (do ((row 0 (+ row 1)))
              ((= row nobs))
            (vector-set! resid row
                         (- (vector-ref resid row)
                            (* (* (- (vector-ref ps (+ wmax row)) (vector-ref ps (- (+ wmax row) w))) invw) (- bnew old)))))))))
  0)

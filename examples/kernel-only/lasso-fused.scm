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
;; sweep spells this expression out inline rather than calling here:
;; under -march=native the compiler contracts multiply-add chains into
;; FMAs, and it decides differently across a call boundary, which moves
;; the last bit. The
;; reciprocal of the window is passed in rather than dividing here: a
;; division per element costs more than the memory the fusion saves, and
;; 1/w is the same for the whole column.
(define (ma-elem ps wmax row w invw)
  (let ((t (+ wmax row)))
    (* (- (vector-ref ps t) (vector-ref ps (- t w))) invw)))

(define (lasso-fused ps beta resid xnorm lam iters nobs p wmax)
  (with-arrays ((resid (nobs)))
    (range-for (sweep iters)
      (range-for (j p)
        (let ((w (+ j 1))
              (invw (/ 1.0 (+ j 1)))
              (old (vector-ref beta j)))
          (let ((rho (+ (range-sum (row nobs)
                          (* (* (- (vector-ref ps (+ wmax row))
                                   (vector-ref ps (- (+ wmax row) w)))
                                invw)
                             (vector-ref resid row)))
                        (* old (vector-ref xnorm j)))))
            (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 nobs)))
                           (vector-ref xnorm j))))
              (vector-set! beta j bnew)
              (range-for (row nobs)
                (array-dec! resid row
                            (* (* (- (vector-ref ps (+ wmax row))
                                     (vector-ref ps (- (+ wmax row) w)))
                                  invw)
                               (- bnew old)))))))))
    0))

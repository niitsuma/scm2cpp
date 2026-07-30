;; A synthetic check for temporal feature selection: y is built from moving
;; averages of x at two window lengths the program is not otherwise told
;; about (5 and 20). Every window length from 1 to WMAX is offered as a
;; candidate feature, and lasso coordinate descent must pick out the two
;; that matter from among all of them.
;;
;; ps is built by the naive O(n^2) box-sum-from-origin nest -- the form -I
;; recognises and rewrites to a rank-1 summed-area table -- rather than the
;; O(n) running-sum a person would normally write, so that whether the
;; rewrite actually fires can be checked from the generated code. Every
;; candidate window's moving average is then an O(1) query against the
;; same table, which is the point: many window lengths share one table
;; rather than each re-summing its own range from scratch.

(define (soft-threshold z g)
  (cond ((> z g) (- z g))
        ((< z (- 0.0 g)) (+ z g))
        (else 0.0)))

(define (lasso x beta resid xnorm lam iters n p)
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
          (do ((i 0 (+ i 1)))
              ((= i n))
            (vector-set! resid i
                         (- (vector-ref resid i)
                            (* (vector-ref x (+ (* j n) i)) (- bnew old)))))))))
  0)

(define (main)
  (let ((n 400)
        (wmax 40)
        (nobs 360)
        (p 40)
        (seed 98765)
        (x (make-vector 400 0.0))
        (ps (make-vector 400 0.0))
        (xd (make-vector 14400 0.0))
        (y (make-vector 360 0.0))
        (xnorm (make-vector 40 0.0))
        (beta (make-vector 40 0.0))
        (resid (make-vector 360 0.0))
        (trueW1 5) (trueB1 2.0)
        (trueW2 20) (trueB2 -1.5))

    ;; A pseudo-random base sequence, scaled to [0,10). Park-Miller via
    ;; Schrage's method, so every intermediate product stays within 32-bit
    ;; signed range -- the plain int scm2cpp maps Scheme integers to,
    ;; unlike Racket's own unbounded integers.
    (do ((k 0 (+ k 1))) ((= k n))
      (let ((hi (quotient seed 127773)))
        (let ((lo (remainder seed 127773)))
          (let ((test (- (* 16807 lo) (* 2836 hi))))
            (if (> test 0)
                (set! seed test)
                (set! seed (+ test 2147483647))))))
      (vector-set! x k (* 10.0 (/ (* 1.0 seed) 2147483647.0))))

    ;; ps[i] = sum_{a=0}^{i} x[a], written the naive way on purpose.
    (do ((i 0 (+ i 1))) ((= i n))
      (let ((acc 0.0))
        (do ((a 0 (+ a 1))) ((= a (+ i 1)))
          (set! acc (+ acc (vector-ref x a))))
        (vector-set! ps i acc)))

    ;; Every candidate window's moving average, each an O(1) query against
    ;; the one table above.
    (do ((w 1 (+ w 1))) ((= w (+ wmax 1)))
      (do ((row 0 (+ row 1))) ((= row nobs))
        (let ((t (+ wmax row)))
          (vector-set! xd (+ (* (- w 1) nobs) row)
                       (/ (- (vector-ref ps t) (vector-ref ps (- t w)))
                          (* 1.0 w))))))

    ;; The signal: built from two window lengths the lasso pass below is
    ;; not told about, using the same candidate features it will search.
    (do ((row 0 (+ row 1))) ((= row nobs))
      (vector-set! y row
                   (+ (* trueB1 (vector-ref xd (+ (* (- trueW1 1) nobs) row)))
                      (* trueB2 (vector-ref xd (+ (* (- trueW2 1) nobs) row))))))

    (do ((j 0 (+ j 1))) ((= j p))
      (let ((s 0.0))
        (do ((row 0 (+ row 1))) ((= row nobs))
          (set! s (+ s (* (vector-ref xd (+ (* j nobs) row))
                          (vector-ref xd (+ (* j nobs) row))))))
        (vector-set! xnorm j s)))

    (do ((row 0 (+ row 1))) ((= row nobs))
      (vector-set! resid row (vector-ref y row)))

    (lasso xd beta resid xnorm 0.02 20000 nobs p)

    (display "selected windows (|beta|>1e-6):") (newline)
    (do ((j 0 (+ j 1))) ((= j p))
      (if (> (abs (vector-ref beta j)) 0.000001)
          (begin
            (display "  w=") (display (+ j 1))
            (display "  beta_hat=") (display (vector-ref beta j))
            (newline))
          0))

    (display "beta at true windows: w=") (display trueW1)
    (display " -> ") (display (vector-ref beta (- trueW1 1)))
    (display "   w=") (display trueW2)
    (display " -> ") (display (vector-ref beta (- trueW2 1)))
    (newline)

    (let ((maxdiff 0.0) (maxother 0.0))
      (do ((row 0 (+ row 1))) ((= row nobs))
        (let ((yhat 0.0))
          (do ((j 0 (+ j 1))) ((= j p))
            (set! yhat (+ yhat (* (vector-ref beta j) (vector-ref xd (+ (* j nobs) row))))))
          (set! maxdiff (max maxdiff (abs (- (vector-ref y row) yhat))))))
      (do ((j 0 (+ j 1))) ((= j p))
        (if (and (not (= (+ j 1) trueW1)) (not (= (+ j 1) trueW2)))
            (set! maxother (max maxother (abs (vector-ref beta j))))
            0))
      (display "max|beta| among the other 38 windows = ") (display maxother) (newline)
      (display "max|y-yhat| = ") (display maxdiff) (newline))
    0))

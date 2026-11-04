;; The moments of a moving-average design, written as they are defined:
;; feature w at row i is the mean of the w+1 prices up to wmax+i, a
;; for/sum over its window; G = X X' and c = X y are dots of rows.
;; --derive raises the window to a slice sum (R8), reads it off the
;; prices' prefix sums (prefix), lowers the Gram to lag tables (lower)
;; and, there being no sweep to difference, guards the result by the
;; two cost polynomials at run time (cost-guard).  The first call is
;; large enough for the derived body, the second (wmax far beyond
;; nobs and p) takes the body as written.
(define (tfs-moments ps y x g c nobs wmax p)
  (with-arrays ((ps ((+ wmax nobs))) (y (nobs)) (x (p nobs)) (g (p p)) (c (p)))
    (range-for (w p)
      (range-for (i nobs)
        (array-set! x w i
                    (/ (for/sum ((a (in-range (+ w 1))))
                         (vector-ref ps (- (+ wmax i) a)))
                       (* 1.0 (+ w 1))))))
    (range-for (j p)
      (range-for (k p)
        (array-set! g j k (array-sum (* (row x j) (row x k))))))
    (range-for (j p)
      (vector-set! c j (array-sum (* (row x j) y))))
    0))

(define (run nobs wmax p)
  (let* ((n (+ wmax nobs))
         (ps (make-vector n 0.0)) (y (make-vector nobs 0.0))
         (x (make-vector (* p nobs) 0.0)) (g (make-vector (* p p) 0.0))
         (c (make-vector p 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! ps i (* 0.25 (remainder (* i 7) 11))))
    (do ((i 0 (+ i 1))) ((= i nobs))
      (vector-set! y i (* 0.5 (remainder (* i 5) 7))))
    (tfs-moments ps y x g c nobs wmax p)
    (do ((s 0 (+ s 1))) ((= s (* p p))) (display (vector-ref g s)) (display " "))
    (do ((s 0 (+ s 1))) ((= s p)) (display (vector-ref c s)) (display " "))
    (newline)))

(define (main)
  (run 30 6 6)
  (run 3 200 2)
  0)

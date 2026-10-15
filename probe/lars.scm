;; lars.scm on the Gram and correlations of a small correlated design
;; (computed here from five centred rows of four features): method
;; "lar" to the end and "lasso" at alpha 0.05, translated plainly; the
;; oracle runs the same program.  Prints the step counts and the
;; coefficients.
(include "../examples/kernel-only/lars.scm")

(define (main)
  (let ((n 5) (p 4)
        (x (vector 1.0 0.75 0.5 -0.5   -1.0 -0.5 -1.0 0.5   0.5 0.25 1.0 -1.0
                   -0.5 -0.75 -0.25 0.75   0.0 0.25 -0.25 0.25))
        (y (vector 2.0 -1.75 1.25 -1.5 0.0))
        (g (make-vector 16 0.0))
        (cov (make-vector 4 0.0))
        (coef (make-vector 4 0.0)))
    (do ((round 0 (+ round 1))) ((= round 2))
      (do ((a 0 (+ a 1))) ((= a p))
        (let ((acc 0.0))
          (do ((i 0 (+ i 1))) ((= i n))
            (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref y i)))))
          (vector-set! cov a acc))
        (do ((b 0 (+ b 1))) ((= b p))
          (let ((acc 0.0))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref x (+ (* i p) b))))))
            (vector-set! g (+ (* a p) b) acc))))
      (let ((it (lars g cov coef 5.0 (if (= round 0) 0.0 0.05) round 500 2.220446049250313e-16 p)))
        (display it) (display " ")
        (do ((j 0 (+ j 1))) ((= j p))
          (display (vector-ref coef j)) (display " "))
        (newline)))
    0))

;; lars.scm on the Gram and correlations of a small correlated design
;; (computed here from five centred rows of four features): method
;; "lar" to the end and "lasso" at alpha 0.05, then the whole "lasso"
;; path recorded (lars_path(return_path=True)); translated plainly, the
;; oracle runs the same program.  Prints the step counts and the
;; coefficients, then the path's alphas and its rows.
(include "../examples/kernel-only/lars.scm")

(define (main)
  (let ((n 5) (p 4)
        (x (vector 1.0 0.75 0.5 -0.5   -1.0 -0.5 -1.0 0.5   0.5 0.25 1.0 -1.0
                   -0.5 -0.75 -0.25 0.75   0.0 0.25 -0.25 0.25))
        (y (vector 2.0 -1.75 1.25 -1.5 0.0))
        (g (make-vector 16 0.0))
        (cov (make-vector 4 0.0))
        (coef (make-vector 4 0.0)))
   ;; the path's buffers runtime-sized: 9 rows for at most 8 steps
   (let ((path (make-vector (* 9 p) 0.0)) (alphas (make-vector 9 0.0)))
    (do ((round 0 (+ round 1))) ((= round 3))
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
      (if (< round 2)
          (let ((it (lars g cov coef path alphas 0 5.0 (if (= round 0) 0.0 0.05) round 500
                          2.220446049250313e-16 p)))
            (display it) (display " ")
            (do ((j 0 (+ j 1))) ((= j p))
              (display (vector-ref coef j)) (display " "))
            (newline))
          (let ((it (lars g cov coef path alphas 1 5.0 0.0 1 8 2.220446049250313e-16 p)))
            (display it) (newline)
            (do ((s 0 (+ s 1))) ((> s it))
              (display (vector-ref alphas s)) (display " ")
              (do ((j 0 (+ j 1))) ((= j p))
                (display (vector-ref path (+ (* s p) j))) (display " "))
              (newline)))))
    0)))

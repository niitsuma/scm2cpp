;; lbfgs.scm through its two objectives (lbfgs-objectives.scm) on twelve
;; points in two features: LogisticRegression(solver="lbfgs") with two
;; classes and with three, and HuberRegressor with an outlier (the scale
;; bounded below, the bound fixing it at the first Cauchy point).
;; Translated plainly and with --blas; the oracle runs the same program.
;; Prints, for each, the iteration count and the parameters.
(include "../examples/kernel-only/lbfgs-objectives.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 12) (p 2)
        (x (vector 1.0 0.5  -0.5 1.0  2.0 -1.0  -1.5 -0.5  0.5 2.0  -1.0 1.5
                   1.5 0.5  -2.0 -1.0  0.25 -0.75  -0.5 -2.0  1.0 -1.5  -0.75 0.25))
        (y2 (vector 1.0 0.0 1.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0 1.0 0.0))
        (y3 (vector 0.0 1.0 2.0 1.0 0.0 1.0 2.0 1.0 0.0 0.0 2.0 1.0))
        (yr (vector 1.5 -0.25 2.5 -1.75 1.0 -0.5 2.0 -2.5 0.75 -1.25 9.0 0.5))
        (out (make-vector 2 0.0)))
    ;; one kind of vector for the parameters: runtime-sized
    (let ((c2 (make-vector (+ p 1) 0.0))
          (c3 (make-vector (* 3 (+ p 1)) 0.0))
          (ch (make-vector (+ p 2) 0.0)))
    (display (logistic-lbfgs x y2 c2 out 1.0 100 0.0001 0 1 n p 1)) (display " ")
    (show c2 3)
    (display (logistic-lbfgs x y3 c3 out 0.5 100 0.0001 1 1 n p 3)) (display " ")
    (show c3 9)
    (vector-set! ch 3 1.0)
    (display (huber x yr ch out 1.35 0.0001 100 0.00001 1 n p)) (display " ")
    (show ch 4)
    0)))

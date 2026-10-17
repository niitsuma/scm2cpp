;; ard.scm on ten centred points in three features, the third a weak
;; one, with the kept features' Gram formed every iteration (HOIST 0,
;; scikit-learn's way) and taken from X'X (HOIST 1).  Translated plainly,
;; with --blas and with --derive (which hoists HOIST 0's Gram); the oracle runs the same program.  Prints, for each,
;; the iterations, the coefficients, the lambdas, alpha and the number
;; of features kept.
(include "../examples/kernel-only/ard.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 10) (p 3)
        (x (vector 1.0 0.5 0.25  -0.5 1.0 -0.25  0.75 -1.0 0.5  -1.25 0.25 0.0  0.5 0.75 -0.5
                   -0.75 -0.5 0.25  1.5 -0.25 -0.25  -1.0 -0.75 0.0  0.25 1.25 0.25  -0.5 -1.25 -0.25))
        (y (vector 1.5 -1.25 2.0 -2.25 0.25 -0.5 2.75 -1.0 -0.5 -1.0))
        (out (make-vector 2 0.0)))
    (let ((coef (make-vector p 0.0))
          (lam (make-vector p 0.0))
          (sigma (make-vector (* p p) 0.0)))
      (do ((hoist 0 (+ hoist 1))) ((= hoist 2))
        (display (ard x y coef sigma lam out 300 0.001 0.000001 0.000001 0.000001 0.000001
                      10000.0 hoist n p))
        (display " ")
        (show coef 3)
        (show lam 3)
        (display (vector-ref out 0)) (display " ") (display (vector-ref out 1)) (newline)))
    0))

;; svm-l1.scm (liblinear's solve_l1r_l2_svc) on twelve points in three
;; features stored by columns, the third a ones column for the bias.
;; Translated plainly; the oracle runs the same program (the same
;; Park-Miller draws).  Prints the outer iterations and the weights.
(include "../examples/kernel-only/svm-l1.scm")

(define (main)
  (let ((n 12) (p 3)
        (x (vector 1.0 0.5 -0.5 2.0 -1.5 0.25 1.5 -1.0 0.75 -0.25 1.25 -2.0
                   0.5 1.0 -1.0 0.25 -0.5 1.5 -0.75 -1.25 1.0 0.5 -0.25 -0.5
                   1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0))
        (y (vector 1.0 1.0 -1.0 1.0 -1.0 1.0 1.0 -1.0 1.0 -1.0 1.0 -1.0))
        (w (make-vector 3 0.0)))
    (display (svm-l1 x y w 1.0 0.0001 1000 1 n p)) (display " ")
    (do ((j 0 (+ j 1))) ((= j p))
      (display (vector-ref w j)) (display " "))
    (newline)
    0))

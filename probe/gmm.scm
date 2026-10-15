;; gmm.scm on twelve points in two features, two components, the start
;; the one-hot labels of two clusters (one point given to the wrong
;; one).  Translated plainly and with --blas; the oracle runs the same
;; program.  Prints the iterations, the weights, the means, the first
;; precision factor and the labels.
(include "../examples/kernel-only/gmm.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 12) (p 2) (kc 2)
        (x (vector 0.0 0.5  0.5 0.25  -0.25 0.0  0.75 -0.5  0.25 0.75  -0.5 -0.25
                   4.0 3.5  4.5 4.25  3.75 4.0  4.25 3.0  3.5 4.5  5.0 3.75))
        (resp (vector 1.0 0.0  1.0 0.0  1.0 0.0  1.0 0.0  1.0 0.0  0.0 1.0
                      0.0 1.0  0.0 1.0  0.0 1.0  0.0 1.0  0.0 1.0  0.0 1.0))
        (out (make-vector 2 0.0)))
    ;; one kind of vector for the results: runtime-sized
    (let ((weights (make-vector kc 0.0))
          (means (make-vector (* kc p) 0.0))
          (prec (make-vector (* kc (* p p)) 0.0))
          (labels (make-vector n 0.0)))
    (display (gmm x resp weights means prec labels out 100 0.001 0.000001 n p kc)) (display " ")
    (display (vector-ref out 0)) (newline)
    (show weights 2)
    (show means 4)
    (show prec 4)
    (show labels 12)
    0)))

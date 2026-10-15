;; fscore.scm, rfe.scm and gram.scm on ten points in four features:
;; f_regression for two targets, f_classif for three classes, RFE around
;; ridge down to two features (one at a time, the Cholesky factor
;; downdated), and the two Gram products.  Translated plainly and with
;; --blas; the oracle runs the same program.
(include "../examples/kernel-only/fscore.scm")
(include "../examples/kernel-only/rfe.scm")
(include "../examples/kernel-only/gram.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((n 10) (p 4)
        (x (vector 1.0 0.5 -0.5 0.25  -0.5 1.0 0.75 -1.0  2.0 -1.0 0.5 0.5  -1.5 -0.5 -1.0 0.75
                   0.5 2.0 0.25 -0.5  -1.0 1.5 -0.75 1.0  1.5 0.5 1.0 -0.25  0.25 -0.75 -0.5 1.5
                   -0.5 -2.0 1.5 0.0  1.0 -1.5 -0.25 -1.25))
        (y2 (vector 1.5 -0.25 2.5 -1.75 1.0 -0.5 2.0 -2.5 0.75 -1.25
                    0.5 1.0 -0.5 0.25 2.0 -1.0 1.5 0.0 -0.75 1.25))
        (lab (vector 0 1 2 0 1 2 0 1 2 0)))
    (let ((r (make-vector (* p 2) 0.0)) (f (make-vector (* p 2) 0.0))
          (fc (make-vector p 0.0)) (coef (make-vector p 0.0))
          (support (make-vector p 0)) (ranking (make-vector p 0))
          (g (make-vector (* p p) 0.0)) (c (make-vector (* p 2) 0.0)))
      (f-regression x y2 r f 1 n p 2)
      (show f 8)
      (f-classif x lab fc n p 3)
      (show fc 4)
      (display (rfe x y2 coef support ranking 1.0 2 1 n p)) (display " ")
      (show coef 4)
      (do ((j 0 (+ j 1))) ((= j p)) (display (vector-ref ranking j)) (display " "))
      (newline)
      (gram-xx x g n p)
      (show g 16)
      (gram-xy x y2 c n p 2)
      (show c 8))
    0))

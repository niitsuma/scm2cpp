;; ransac.scm on twelve points of y = 2 x1 - x2 + 1 with two gross
;; outliers, the subsets given (as the package draws them from
;; scikit-learn's random_state): translated plainly; the oracle runs the
;; same program.  Prints the trial count, the slope, the intercept and
;; the inlier mask.
(include "../examples/kernel-only/ransac.scm")

(define (main)
  (let ((n 12) (p 2)
        (x (vector 0.0 0.0  1.0 0.0  0.0 1.0  1.0 1.0  2.0 0.5  0.5 2.0
                   1.5 1.0  -1.0 0.5  0.5 -1.0  2.0 2.0  -0.5 -0.5  1.0 -1.5))
        (y (vector 1.0 3.0 0.0 2.0 4.5 0.0 3.0 -1.5 9.0 3.0 0.5 -4.0))
        (subsets (vector 0 1 2  8 9 11  3 4 5  1 6 7  2 3 10))
        (coef (make-vector 2 0.0))
        (mask (make-vector 12 0.0))
        (out (make-vector 1 0.0)))
    (let ((t (ransac x y subsets coef mask out 5 3 0.25 0.99 n p)))
      (display t) (newline)
      (display (vector-ref coef 0)) (display " ")
      (display (vector-ref coef 1)) (display " ")
      (display (vector-ref out 0)) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref mask i)) (display " "))
      (newline))
    0))

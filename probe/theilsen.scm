;; theilsen.scm on eight points in two features with one outlier: all 56
;; three-row subsets (the combinations scikit-learn takes when there are
;; few), each solved exactly (one subset of collinear points by the
;; minimum-norm fit), then the spatial median; and a one-feature fit
;; without intercept over the same subsets (least squares on three rows,
;; then the median branch).  Translated plainly; the
;; oracle runs the same program.  Prints the step index and the median.
(include "../examples/kernel-only/theilsen.scm")

(define (main)
  (let ((n 8) (p 2)
        (x (vector 1.0 0.5  -0.5 1.0  2.0 -1.0  -1.5 -0.5  0.5 2.0  -1.0 1.5  1.5 0.5  0.25 -0.75))
        (y (vector 3.0 0.25 2.5 -2.75 3.5 0.75 9.0 -0.25))
        (idx (make-vector 168 0))
        (w (make-vector 168 0.0))
        (coef (make-vector 3 0.0))
        (s 0))
    ;; the combinations of three rows in lexicographic order
    (do ((a 0 (+ a 1))) ((= a n))
      (do ((b (+ a 1) (+ b 1))) ((>= b n))
        (do ((c (+ b 1) (+ c 1))) ((>= c n))
          (vector-set! idx (* 3 s) a)
          (vector-set! idx (+ (* 3 s) 1) b)
          (vector-set! idx (+ (* 3 s) 2) c)
          (set! s (+ s 1)))))
    (display (theilsen x y idx w coef 56 3 1 300 0.001 p)) (display " ")
    (do ((j 0 (+ j 1))) ((= j 3)) (display (vector-ref coef j)) (display " "))
    (newline)
    (display (theilsen x y idx w coef 56 3 0 300 0.001 1)) (display " ")
    (display (vector-ref coef 0)) (newline)
    0))

;; svm-kernel.scm with fewer observations than features (3 of 6), so
;; the derivation's guard (if (< n p) ..) takes the kernel-form branch:
;; the memo c = X w over the 3 x 3 kernel matrix X X', the primal
;; vector w restored at the end by X' (alpha . y).  Two of the three
;; labels are -1 and both of those points end with alpha > 0, so a
;; restore that drops the y factor (X' (alpha - alpha0)) prints a
;; different w.
(include "../examples/kernel-only/svm-kernel.scm")

(define (main)
  (let ((n 3) (p 6)
        (x (vector 1.0 0.5 0.0 2.0 -0.5 1.0
                   0.0 1.0 -2.0 -1.0 0.25 0.5
                   0.5 -1.0 0.75 -0.25 0.5 -1.0))
        (y (vector 1.0 -1.0 -1.0))
        (w (make-vector 6 0.0))
        (alpha (make-vector 3 0.0))
        (xnorm (make-vector 3 0.0)))
    (svm x y w alpha xnorm 0.5 30 0.0 n p)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref alpha i)) (display " "))
    (newline)
    (do ((j 0 (+ j 1))) ((= j p))
      (display (vector-ref w j)) (display " "))
    (newline)
    0))

;; svm-dual.scm on the linear kernel of derive-svm.scm's data: K = X X'
;; built here, the sweep run on it.  The dual variables must print
;; exactly what derive-svm.scm prints -- the hand-written kernel form
;; and the derived one are the same sweep -- which is the check that
;; the nonlinear solver is the derivation's output with K swapped.
(include "../examples/kernel-only/svm-dual.scm")

(define (main)
  (let ((n 6) (p 3)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5
                   0.5 -1.0 0.75
                   -0.25 0.5 -1.0))
        (y (vector 1.0 1.0 -1.0 -1.0 1.0 -1.0))
        (k (make-vector 36 0.0))
        (alpha (make-vector 6 0.0))
        (c (make-vector 6 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j n))
        (let ((acc 0.0))
          (do ((l 0 (+ l 1))) ((= l p))
            (set! acc (+ acc (* (vector-ref x (+ (* i p) l))
                                (vector-ref x (+ (* j p) l))))))
          (vector-set! k (+ (* i n) j) acc))))
    (svm-dual k y alpha c 0.5 30 0.0 n)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref alpha i)) (display " "))
    (newline)
    0))

;; svm-liblinear.scm, liblinear's solver whole (random order and
;; shrinking), on the data of derive-svm.scm.  Translated plainly and
;; with --derive: the derivation must leave it alone -- the point a
;; step works on is i = index[s], let-bound, and another loop's
;; counter is also named i, which a name-based analysis would take
;; for a loop coordinate -- so both print what the oracle prints.
(include "../examples/kernel-only/svm-liblinear.scm")

(define (main)
  (let ((n 6) (p 3)
        (x (vector 1.0 0.5 0.0
                   2.0 -0.5 1.0
                   0.0 1.0 -2.0
                   -1.0 0.25 0.5
                   0.5 -1.0 0.75
                   -0.25 0.5 -1.0))
        (y (vector 1.0 1.0 -1.0 -1.0 1.0 -1.0))
        (w (make-vector 3 0.0))
        (alpha (make-vector 6 0.0))
        (xnorm (make-vector 6 0.0)))
    (let ((sweeps (svm-liblinear x y w alpha xnorm 0.5 50 1e-6 7 n p)))
      (display sweeps) (newline)
      (do ((i 0 (+ i 1))) ((= i n))
        (display (vector-ref alpha i)) (display " "))
      (newline)
      (do ((j 0 (+ j 1))) ((= j p))
        (display (vector-ref w j)) (display " "))
      (newline))
    0))

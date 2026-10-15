;; sgd.scm on ten points in two features: SGDClassifier's defaults (the
;; hinge, "optimal") and SGDRegressor's (the squared error,
;; "invscaling", pow included), Perceptron (the hinge at 0, "constant",
;; no penalty), the passive-aggressive classifier ("pa1") and regressor
;; ("pa2", epsilon-insensitive), points in order.  Translated plainly; the
;; oracle runs the same program.  Prints, for each, the epoch count, the
;; weights and the intercept.
(include "../examples/kernel-only/sgd.scm")

(define (main)
  (let ((n 10) (p 2)
        (x (vector 1.0 0.5  -0.5 1.0  2.0 -1.0  -1.5 -0.5  0.5 2.0
                   -1.0 1.5  1.5 0.5  -2.0 -1.0  0.25 -0.75  -0.5 -2.0))
        (yc (vector 1.0 -1.0 1.0 -1.0 1.0 -1.0 1.0 -1.0 1.0 -1.0))
        (yr (vector 1.5 -0.25 2.5 -1.75 1.0 -0.5 2.0 -2.5 0.75 -1.25))
        (w (make-vector 2 0.0))
        (out (make-vector 1 0.0)))
    (let ((ec (sgd x yc w out 0 0 1 0.0001 0.0 0.5 0.1 50 0.001 5 1 n p)))
      (display ec) (display " ")
      (display (vector-ref w 0)) (display " ") (display (vector-ref w 1)) (display " ")
      (display (vector-ref out 0)) (newline))
    (vector-set! w 0 0.0) (vector-set! w 1 0.0)
    (let ((er (sgd x yr w out 1 1 1 0.0001 0.01 0.25 0.1 50 0.001 5 1 n p)))
      (display er) (display " ")
      (display (vector-ref w 0)) (display " ") (display (vector-ref w 1)) (display " ")
      (display (vector-ref out 0)) (newline))
    (do ((run 0 (+ run 1))) ((= run 3))
      (vector-set! w 0 0.0) (vector-set! w 1 0.0)
      (let ((ek (if (= run 0)
                    (sgd x yc w out 2 2 0 0.0001 1.0 0.5 0.1 50 0.001 5 1 n p)
                    (if (= run 1)
                        (sgd x yc w out 0 3 0 0.0001 1.0 0.5 0.1 50 0.001 5 1 n p)
                        (sgd x yr w out 3 4 0 0.0001 1.0 0.5 0.1 50 0.001 5 1 n p)))))
        (display ek) (display " ")
        (display (vector-ref w 0)) (display " ") (display (vector-ref w 1)) (display " ")
        (display (vector-ref out 0)) (newline)))
    0))

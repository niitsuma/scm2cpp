;; lasso-auto called on both sides of its choice: a tall design (four
;; observations of three features) takes the Gram route, a wide one
;; (three observations of four features) the residual route, and the
;; coefficient paths and final residuals of both are printed.  The suite
;; translates this plainly, with --blas and (where a device is) with
;; --cublas -- never with --derive, which would turn the residual route
;; into the Gram route too -- and each must print what Racket prints.
;; The blas rounds must also find the Gram product replaced by the
;; binding's call.  The data are integers over powers of two so the
;; arithmetic orders agree to the last digit.
(include "../examples/kernel-only/lasso-auto.scm")

(define (run-path x y n p lams nlam)
  (let ((beta (make-vector p 0.0))
        (resid (make-vector n 0.0))
        (xnorm (make-vector p 0.0))
        (betas (make-vector (* nlam p) 0.0)))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! resid i (vector-ref y i)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n))
          (set! acc (+ acc (* (vector-ref x (+ (* j n) i))
                              (vector-ref x (+ (* j n) i))))))
        (vector-set! xnorm j acc)))
    (lasso-auto x beta resid xnorm lams betas 20 n p nlam)
    (do ((t 0 (+ t 1))) ((= t (* nlam p)))
      (display (vector-ref betas t)) (display " "))
    (newline)
    (do ((i 0 (+ i 1))) ((= i n))
      (display (vector-ref resid i)) (display " "))
    (newline)
    0))

;; A (vector ...) literal is a fixed-size array in the C++ and so is a
;; make-vector of a constant size, so each design is copied into
;; vectors sized by the arguments for run-path to take both shapes.
(define (gram-case lams nlam n p)
  (let ((xl (vector 1.0 2.0 0.0 -1.0
                    0.5 -0.5 1.0 0.25
                    0.0 1.0 -2.0 0.5))
        (yl (vector 1.0 -1.0 2.0 0.5))
        (x (make-vector (* n p) 0.0))
        (y (make-vector n 0.0)))
    (do ((i 0 (+ i 1))) ((= i (* n p))) (vector-set! x i (vector-ref xl i)))
    (do ((i 0 (+ i 1))) ((= i n)) (vector-set! y i (vector-ref yl i)))
    (run-path x y n p lams nlam)))

(define (resid-case lams nlam n p)
  (let ((xl (vector 1.0 2.0 0.0
                    0.5 -0.5 1.0
                    0.0 1.0 -2.0
                    -1.0 0.25 0.5))
        (yl (vector 1.0 -1.0 2.0))
        (x (make-vector (* n p) 0.0))
        (y (make-vector n 0.0)))
    (do ((i 0 (+ i 1))) ((= i (* n p))) (vector-set! x i (vector-ref xl i)))
    (do ((i 0 (+ i 1))) ((= i n)) (vector-set! y i (vector-ref yl i)))
    (run-path x y n p lams nlam)))

(define (main)
  (let ((lams (vector 0.25 0.0625)))
    (gram-case lams 2 4 3)      ; n = 4 > p = 3: the Gram route
    (resid-case lams 2 3 4)     ; n = 3 <= p = 4: the residual route
    0))

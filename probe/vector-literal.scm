;; (vector e ...) literals: fixed-extent arrays built in one expression.
;; Covers doubles, ints, computed elements, and mutation through a call.
(define (bump! v)
  (vector-set! v 0 (+ (vector-ref v 0) 10))
  0)
(define (main)
  (let ((a (vector 1 2 3))
        (b (vector (+ 1.5 0.5) 4.0 (* 2.0 3.0))))
    (bump! a)
    (display (vector-ref a 0)) (display " ")
    (display (vector-ref a 2)) (display " ")
    (display (vector-ref b 0)) (display " ")
    (display (vector-ref b 2)) (newline)
    0))

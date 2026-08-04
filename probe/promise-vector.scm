;; A promise whose value is a vector, forced more than once. The runtime's
;; promise memoises, so the body must run exactly once however often the
;; promise is forced -- a counter kept in a one-element vector shows that,
;; and shows it identically under Racket and under C++.
(define (build n tick)
  (delay
    (let ((m (make-vector n 0.0)))
      (vector-set! tick 0 (+ (vector-ref tick 0) 1))
      (do ((i 0 (+ i 1))) ((= i n))
        (vector-set! m i (* 2.5 i)))
      m)))
(define (main)
  (let ((tick (make-vector 1 0))
        (n 4))
    (let ((p (build n tick)))
      (let ((a (force p)))
        (display (vector-ref a 3)) (display " "))
      (let ((b (force p)))
        (display (vector-ref b 1)) (display " "))
      (display (vector-ref tick 0))
      (newline)
      0)))

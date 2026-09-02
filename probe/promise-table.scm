;; A table of promises: lazy dynamic programming. Each cell's thunk forces
;; the cells it depends on, so the table fills itself in dependency order
;; and every body runs exactly once -- a counter kept in a one-element
;; vector shows that, and shows it identically under Racket and C++.
;; Three things had to hold for this to translate: force inside a lambda
;; is a primitive, not a captured variable; a vector filled with a
;; promise takes its element type from inference; and forcing counts as
;; a write, so the table is captured by mutable reference and the
;; memoisation lands in the table rather than in a copy (a table forced
;; through a const reference would be exponential and still print the
;; right number).
(define (lazy-fib n tick)
  (let ((tab (make-vector (+ n 1) (delay 0))))
    (do ((i 0 (+ i 1))) ((= i (+ n 1)))
      (vector-set! tab i
                   (delay (begin
                            (vector-set! tick 0 (+ (vector-ref tick 0) 1))
                            (if (< i 2)
                                i
                                (+ (force (vector-ref tab (- i 1)))
                                   (force (vector-ref tab (- i 2)))))))))
    (force (vector-ref tab n))))
(define (main)
  (let ((tick (make-vector 1 0)))
    (display (lazy-fib 40 tick)) (display " ")
    (display (vector-ref tick 0))
    (newline)
    0))

(define (twice f x) (f (f x)))
(define (inc n) (+ n 1))
(define (main) (display (twice inc 5)) (newline) 0)

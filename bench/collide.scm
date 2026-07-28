(define (f x y) (+ x y))
(define (g x y) (+ (f x y) 1))
(define (main) (display (g 1 2)) (newline) 0)

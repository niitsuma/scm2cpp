(define (run-it experiment) (if (experiment) 1 0))
(define (yes) #t)
(define (main) (display (run-it yes)) (newline) 0)

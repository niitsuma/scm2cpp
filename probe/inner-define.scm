(define (outer n)
  (define (inner k) (* k 2))
  (inner n))
(define (main) (display (outer 5)) (newline) 0)

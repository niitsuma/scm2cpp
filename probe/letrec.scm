(define (count-down n)
  (letrec ((go (lambda (k acc) (if (= k 0) acc (go (- k 1) (+ acc k))))))
    (go n 0)))
(define (main) (display (count-down 5)) (newline) 0)


(define (fact n)
   (if (= n 0) 1
                   (* (fact (- n 1)) n)))



(define (main )
   (display (fact 10))
   (newline)
   0

)




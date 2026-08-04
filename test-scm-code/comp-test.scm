;(defmacro cadr (x)
;    (list 'car (list 'cdr x)))


(define (fact n)
   (if (= n 0) 1
                   (* (fact (- n 1)) n)))

(define (fact2-int n)
   (if (= n 0) 1
                   (* (fact2-int (- n 1)) n)))


(define (fact3 n-int)
   (if (= n-int 0) 1
                   (* (fact3 (- n-int 1)) n-int)))

(define (fact-int n-int)
   (if (= n-int 0) 1
                   (* (fact-int (- n-int 1)) n-int)))

(define (factorial n)
  (fact-iter 1 1 n))

(define (fact-iter product counter max-count)
  (if (> counter max-count)
      product
      (fact-iter (* counter product)
                 (+ counter 1)
                 max-count)))

(define (fib n)
  (cond ((= n 0) 0)
        ((= n 1) 1)
        (else (+ (fib (- n 1))
                 (fib (- n 2))))))


(define (main )
  (let ((a 10))
   (display (fact-int a))
   (newline)
   0
    )
)




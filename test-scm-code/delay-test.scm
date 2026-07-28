(define-macro delay 
  (lambda (expr)
    `(make-promise (lambda () ,expr))))


;(define (force promise) (promise))

(define (main)
  (let (
	(a (delay (+ 10 20)))
	(b (delay (+ 1 2)))
	)
    (force a)
    (force b)
    ))
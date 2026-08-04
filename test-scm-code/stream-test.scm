;#lang scheme
;(require "mymacro.scm")

;(define the-empty-stream '())

;(define stream-null? null?)

;; (define-macro delay 
;;   (lambda (expr)
;;     `(make-promise (lambda () ,expr))))

(define-macro delay 
  (lambda (expr)
    `(lambda () ,expr)))


;(define (force promise) (promise))

(define-macro (cons-stream a b)
  `(cons ,a (delay ,b)))

(define (stream-car stream) (car stream))

(define (stream-cdr stream) (force (cdr stream)))

(define (stream-ref s n-int)
  (if (= n-int 0)
      (stream-car s)
      (stream-ref (stream-cdr s) (- n-int 1))))

(define (integers-starting-from n-int)
  (cons-stream  n-int (integers-starting-from (+ n-int 1))))

;(define integers (integers-starting-from 1))

(define (main )
  (let (
        (integers (integers-starting-from 1))
        )
    (display (stream-ref integers 10))
    (newline)
    0
  )
  )

;(main)


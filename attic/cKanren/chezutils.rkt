#lang racket

(provide remp list-sort)

(define (remp proc lst)
  (filter (compose not proc) lst))

(define (list-sort pred lst)
  (sort lst pred))
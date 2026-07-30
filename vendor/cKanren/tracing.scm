#lang racket

(provide trace-define-mk)
(require "mk.scm")

(define-syntax trace-define-mk
  (syntax-rules ()
    ((_ name (λ (a* ...) body))
     (define name
       (λ (a* ...)
         (fresh ()
           (project (a* ...)
             (begin
               (printf "~s\n" (list 'name a* ...))
               succeed))
           body))))
    ((_ (name a* ...) body)
     (define (name a* ...)
       (fresh ()
         (project (a* ...)
           (begin
             (printf "~s\n" (list 'name a* ...))
             succeed))
         body)))))

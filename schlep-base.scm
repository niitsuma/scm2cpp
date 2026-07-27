#lang racket

(provide 
 report
 qreport
 *schlep-input-name*
 *schlep-output-name*
 *procedure*
 set!*procedure*
 *output-line*
 inc-*output-line*
 set!*output-line*
)


(define *schlep-input-name* "stdin")
(define *schlep-output-name* "?")
(define *procedure* #f)
(define *output-line* 0)


;;; REPORT an error or warning
(define report
  (lambda args
    (display *schlep-input-name*)
    (display ": In function `")
    (display *procedure*)
    (display "': ")
    (newline)

    (display *schlep-output-name*)
    (display ": ")
    (display *output-line*)
    (display ": warning: ")
    (apply qreport args)))

(define qreport
  (lambda args
    (for-each (lambda (x) (write x) (display #\space)) args)
    (newline)))


;;;----additiocal module for diviede to sub 

(define (inc-*output-line*)
 (set! *output-line* (+ 1 *output-line*))
)

(define (set!*output-line* x) (set! *output-line* x))

(define (set!*procedure* x) (set! *procedure* x))

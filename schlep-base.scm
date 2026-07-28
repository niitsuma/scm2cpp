#lang racket

;;; This file is derived from scm2c.scm of Schlep by Aubrey Jaffer.
;;; Original: http://people.csail.mit.edu/jaffer/Schlep/scm2c
;;;
;;; Copyright (C) 1991-2006 Aubrey Jaffer and Radey Shouman
;;; Copyright (C) 2008, 2009 Aubrey Jaffer
;
;Permission to copy this software, to modify it, to redistribute it,
;to distribute modified versions, and to use it for any purpose is
;granted, subject to the following restrictions and understandings.
;
;1.  Any copy made of this software must include this copyright notice
;in full.
;
;2.  I have made no warranty or representation that the operation of
;this software will be error-free, and I am under no obligation to
;provide any services, by way of maintenance, update, or otherwise.
;
;3.  In conjunction with products arising from the use of this
;material, there shall be no use of my name in any advertising,
;promotional, or sales literature without prior written consent in
;each case.
;
;;; Modifications for C++ output and for Racket:
;;; Copyright (C) 2011-2026 Hirotaka Niitsuma

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

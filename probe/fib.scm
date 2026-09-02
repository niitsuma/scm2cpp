;; Fibonacci the two ways the subset memoises, side by side, so the
;; idioms can be read against each other on the one function everyone
;; knows.  Neither is found by a rewrite: the tabulation rule that once
;; turned a tree recursion into a table-filling loop went with the
;; rule search (CHANGES.ja.md section 78), and what the translator
;; offers instead are these two shapes, written by hand.
;;
;;   fib-memo   memoisation through a hash table: the function consults
;;              the table before running its body and records the
;;              result after.  The table grows with the arguments
;;              actually asked for, so nothing has to be sized in
;;              advance -- the shape for an argument that is not a
;;              small integer index (probe/hash-memo.scm memoises
;;              Collatz this way).
;;   fib-lazy   a vector of promises: cell i's thunk forces the cells it
;;              depends on, so the table fills itself in dependency
;;              order.  The evaluation order the tabulation rule used
;;              to resolve statically is here discovered at run time by
;;              the forcing (probe/promise-table.scm is the same shape
;;              with the notes on what had to hold to translate it).
;;
;; A counter in a one-element vector shows each body runs once under
;; either: fib(40) = 102334155 after 41 evaluations, in Racket and in
;; the C++.  The naive recursion is beside them as the reference, run
;; where it can still be afforded.

(include "define-memo.scm")

(define (fib-naive n)
  (if (< n 2) n (+ (fib-naive (- n 1)) (fib-naive (- n 2)))))

(define fib-table (make-hash))
(define memo-tick (make-vector 1 0))
(define-memo fib-table (fib-memo n)
  (vector-set! memo-tick 0 (+ (vector-ref memo-tick 0) 1))
  (if (< n 2) n (+ (fib-memo (- n 1)) (fib-memo (- n 2)))))

(define (fib-lazy n tick)
  (let ((tab (make-vector (+ n 1) (delay 0))))
    (do ((i 0 (+ i 1))) ((= i (+ n 1)))
      (vector-set! tab i
                   (delay (begin
                            (vector-set! tick 0 (+ (vector-ref tick 0) 1))
                            (if (< i 2)
                                i
                                (+ (force (vector-ref tab (- i 1)))
                                   (force (vector-ref tab (- i 2)))))))))
    (force (vector-ref tab n))))

(define (main)
  (let ((lazy-tick (make-vector 1 0)))
    (display (fib-naive 20)) (newline)
    (display (fib-memo 40)) (display " ")
    (display (vector-ref memo-tick 0)) (newline)
    (display (fib-lazy 40 lazy-tick)) (display " ")
    (display (vector-ref lazy-tick 0)) (newline)
    0))

;; Hash tables: Racket's make-hash / hash-ref / hash-set! / hash-has-key?
;; / hash-count over one key type and one value type, as std::unordered_map
;; (std::map when the key is itself a container). Two uses: a table keyed
;; by strings, and memoisation of a recursive function whose argument is
;; not a small integer index -- the table grows with the calls actually
;; made, where a vector would have to be sized for the largest argument
;; in advance. A counter in a one-element vector shows each body runs
;; once, under Racket and under C++ alike.
(include "define-memo.scm")   ; the define-memo macro, shared with fib.scm

(define (tally! h w)
  (hash-set! h w (+ 1 (hash-ref h w 0)))
  0)

(define collatz-memo (make-hash))
(define tick (make-vector 1 0))
;; Steps to reach 1; the arguments visited are sparse and go far above n.
(define-memo collatz-memo (collatz n)
  (vector-set! tick 0 (+ (vector-ref tick 0) 1))
  (cond ((= n 1) 0)
        ((= (remainder n 2) 0) (+ 1 (collatz (quotient n 2))))
        (else (+ 1 (collatz (+ (* 3 n) 1))))))

(define (main)
  (let ((h (make-hash)))
    (tally! h "apple") (tally! h "pear") (tally! h "apple")
    (display (hash-ref h "apple")) (display " ")
    (display (hash-ref h "pear")) (display " ")
    (display (hash-ref h "plum" 0)) (display " ")
    (display (hash-count h)) (newline))
  (let ((s 0))
    (do ((i 1 (+ i 1))) ((> i 30))
      (set! s (+ s (collatz i))))
    (display s) (display " ")
    (display (vector-ref tick 0)) (display " ")
    (display (hash-count collatz-memo))
    (newline))
  0)

;; Closures over variables that set! changes.  A closure struct holds its
;; captures by value, so before assignment conversion each side kept its
;; own copy: a counter forgot its count, and an accumulator written from
;; vector-for-each read 0 afterwards, silently.  Such a variable now
;; lives in a scm2cpp::box, one cell shared by every copy of the handle.
;; Only explicit lambdas count as capturing: the do loop's t below stays
;; a plain variable.  A closure in a function's tail is returned.
(define (make-counter)
  (let ((n 0)) (lambda () (set! n (+ n 1)) n)))

;; over an array parameter, a span: the traversals index it
(define (sum-of v)
  (let ((s 0)) (vector-for-each (lambda (x) (set! s (+ s x))) v) s))
(define (fill-all! v) (vector-fill! v 7))

;; an assigned parameter, one cell per call
(define (make-from start)
  (lambda () (set! start (+ start 10)) start))

(define (main)
  (let ((c (make-counter)) (d (make-counter)))
    (c) (c)
    (display (c)) (display " ") (display (d)) (newline))
  (let ((f (make-from 5)) (g (make-from 100)))
    (f)
    (display (f)) (display " ") (display (g)) (newline))
  ;; a let-bound closure and the scope that made it share n
  (let ((n 0))
    (let ((inc (lambda () (set! n (+ n 1)))))
      (inc) (inc) (inc)
      (display n) (newline)))
  ;; an accumulator written from a traversal
  (let ((v (make-vector 5 2)) (s 0))
    (vector-for-each (lambda (x) (set! s (+ s x))) v)
    (display s) (newline))
  (let ((w (make-vector 3 0)))
    (fill-all! w)
    (display (sum-of w)) (newline))
  ;; an internal define, written from a lambda
  (define total 0)
  (vector-for-each (lambda (x) (set! total (+ total x))) (make-vector 4 3))
  (display total) (newline)
  ;; a closure inside a closure, and a reader that sees a later set!
  (let ((m 0))
    (let ((outer (lambda () (let ((inner (lambda () (set! m (+ m 1))))) (inner) (inner)))))
      (outer) (outer)
      (display m) (newline)))
  (let ((r 1))
    (let ((get (lambda () (* r 10))))
      (set! r 7)
      (display (get)) (newline)))
  ;; the box's type widens with the values set! stores
  (let ((acc 0))
    (let ((add (lambda () (set! acc (+ acc 1.5)))))
      (add) (add)
      (display acc) (newline)))
  ;; a loop's own assignment needs no box
  (let ((t 0))
    (do ((i 0 (+ i 1))) ((= i 10)) (set! t (+ t i)))
    (display t) (newline))
  0)

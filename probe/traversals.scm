;; vector-map, vector-for-each, vector-fill!, list map and for-each,
;; dynamic-wind and error (scm2cpp.hpp).  vector-map's result converts
;; to the container its variable was given: an integer array is int
;; though the lambda returns std::int64_t.  dynamic-wind is a guard
;; whose destructor runs the after thunk, so a void thunk needs nothing
;; of its own.  error throws; its value converts to whatever the other
;; branch of the if is.  A program's own top-level definition of one of
;; these names shadows the built-in (probe/own-builtins.scm).
(define (scale v k) (vector-map (lambda (x) (* k x)) v))

(define (safe-sqrt x) (if (< x 0.0) (error "negative:" x) (sqrt x)))

(define (main)
  (let ((v (make-vector 4 1.5)) (iv (vector 1 2 3)))
    (vector-fill! v 2.5)
    (let ((w (scale v 2.0)))
      (vector-for-each (lambda (x) (display x) (display " ")) w)
      (display (vector-ref (vector-map (lambda (x) (+ x 1.0)) w) 3)))
    (newline)
    (let ((sq (vector-map (lambda (x) (* x x)) iv)))
      (display (vector-ref sq 2)) (newline)))
  (for-each (lambda (x) (display x) (display " ")) (map (lambda (x) (* x x)) (list 1 2 3)))
  (newline)
  (display (dynamic-wind (lambda () (display "[")) (lambda () 42) (lambda () (display "]"))))
  (newline)
  (dynamic-wind (lambda () (display "<")) (lambda () (display "body")) (lambda () (display ">")))
  (newline)
  (display (safe-sqrt 6.25)) (newline)
  0)

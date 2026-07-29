;; Unary - and /, and the short-circuit operators.  A one-argument - used to
;; lose its sign silently, because the variadic case joined the operands with
;; the operator and a single element has nothing to join.
(define (main)
  (let ((a 10) (b 3) (x 4.0) (i 3) (j 0) (k 5))
    (display (+ a (- b))) (newline)
    (display (- b))       (newline)
    (display (- a b 2))   (newline)
    (display (/ x))       (newline)
    (if (and (> i 0) (> k 0)) (display 1) (display 0)) (newline)
    (if (and (> i 0) (> j 0)) (display 1) (display 0)) (newline)
    (if (or  (> j 0) (> k 0)) (display 1) (display 0)) (newline)
    (if (not (and (> j 0) (> k 0))) (display 1) (display 0)) (newline)
    0))

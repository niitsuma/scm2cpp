;; A program's own top-level definition of a name the runtime provides
;; (map, error here) is the one called: neither the inferencer's
;; built-in rule nor the emitter's name table applies to it.
(define (map f n) (+ (f n) 100))
(define (error x) (* x 2))
(define (main)
  (display (map (lambda (x) (* x x)) 3)) (display " ") (display (error 21)) (newline)
  0)

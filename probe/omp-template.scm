;; A parallel loop inside a function template.  SCALE-ANY never reads
;; E and nothing calls it, so E's type stays open and the function is a
;; C++ template (as sym-eigen-top is when --blas lowers every call of
;; it).  Under -P omp its loop carries the directive, and g++ takes only
;; OpenMP's canonical increments inside a template (v += s, not
;; v = (v+s)), at the definition, called or not.  SCALE is the same loop
;; with every type known, run for the output.
(define (scale-any v e n s)
  (do ((i 0 (+ i 1))) ((= i n))
    (vector-set! v i (* s (exact->inexact (+ i 1)))))
  0)

(define (scale v n s)
  (do ((i 0 (+ i 1))) ((= i n))
    (vector-set! v i (* s (exact->inexact (+ i 1)))))
  0)

(define (main)
  (let ((v (make-vector 8 0.0)))
    (scale v 8 0.5)
    (do ((i 0 (+ i 1))) ((= i 8))
      (display (vector-ref v i)) (display " "))
    (newline)
    0))

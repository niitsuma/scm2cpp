;; A growable sequence: the translator has no primitive for it, and the
;; operations below only mean something once a binding maps them onto an
;; existing library class. binding-propose asks a model which class.
(define (fill-squares v n)
  (do ((i 0 (+ i 1))) ((= i n))
    (vec-push! v (+ 0.5 (* 1.0 (* i i)))))
  0)

(define (main)
  (let ((v (vec-new)))
    (fill-squares v 5)
    (display (vec-ref v 3)) (newline)
    (display (vec-len v)) (newline)
    0))

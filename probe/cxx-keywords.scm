;; Scheme names that spell C++ keywords -- a function delete, parameters
;; class and new, locals case and int, this and switch in main -- are
;; emitted with the suffix _scm (schlep-symbol), so the program compiles
;; and prints what the oracle prints.
(define (delete class new)
  (let ((case 0.0))
    (do ((int 0 (+ int 1))) ((= int 3))
      (set! case (+ case (* class (vector-ref new int)))))
    case))

(define (main)
  (let ((this (vector 1.0 2.0 3.0)) (switch 2.0))
    (display (delete switch this)) (newline)
    0))

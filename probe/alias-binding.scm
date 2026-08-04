;; A let binding whose initialiser is another container variable names the
;; same vector in Scheme, so a write through either name is visible through
;; the other and to a function the alias is passed to.
;;
;; Re-pointing such a name with set! is deliberately not exercised here: a
;; C++ reference cannot be re-pointed, the emitter falls back to a copy, and
;; the two languages then disagree. The emitter warns when it sees that,
;; and the limitation is in README.
(define (touch! v)
  (vector-set! v 0 99.5)
  0)
(define (main)
  (let ((areal (make-vector 3 1.0)))
    (let ((ar areal))
      (vector-set! ar 1 42.0)     ; through the alias
      (touch! ar))                ; and through a call taking the alias
    (let ((again areal))
      (vector-set! again 2 5.0))  ; a second alias, after the first is gone
    (display (vector-ref areal 0)) (display " ")
    (display (vector-ref areal 1)) (display " ")
    (display (vector-ref areal 2))
    (newline)
    0))

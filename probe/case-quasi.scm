;; case and quasiquote, normalised by the pre-pass (rewrite-named-let):
;; case to a cond over the key bound once (= for a number datum, eqv?
;; otherwise), quasiquote to the list / append it builds.  Symbols are
;; scm2cpp::symbol, a compile-time hash of the name, so a case over
;; symbols compares two integers.  A variable named case (cxx-keywords
;; has one) is not a case form and is left alone.  (A list literal whose
;; elements mix a literal and a computed integer is a separate, older
;; limitation of list emission, so the templates here avoid it.)
(define (grade x)
  (case (quotient x 10) ((10 9) 4) ((8) 3) ((7) 2) (else 0)))

(define (vowel? c)
  (case (char-downcase c) ((#\a #\e #\i #\o #\u) #t) (else #f)))

(define (op-apply op a b)
  (case op ((add) (+ a b)) ((mul) (* a b)) (else 0)))

(define (main)
  (display (grade 95)) (display (grade 81)) (display (grade 70)) (display (grade 42)) (newline)
  (display (vowel? #\E)) (display " ") (display (vowel? #\z)) (newline)
  (display (op-apply 'add 3 4)) (display " ") (display (op-apply 'mul 3 4)) (display " ")
  (display (op-apply 'neg 3 4)) (newline)
  (display (eq? (string->symbol "add") 'add)) (display " ") (display (symbol->string 'xyz)) (newline)
  (let ((x 2) (ys (list 5 6)))
    (display (list-ref `(1 ,x 3) 1)) (display " ")
    (display (list-ref `(0 ,@ys 9) 2)) (newline))
  0)

#lang racket
;;;; The derivation check: incrementalize the naive fold-form sweep and
;;;; confirm the derived program prints exactly what the naive one does.
;;;; Both programs run through the test oracle, so the built-in array
;;;; layer expands identically for the two; the derived one must also
;;;; actually contain the hoisted Gram kernel -- otherwise "derived" was
;;;; an identity.

(require (file "rewrite-incremental.scm"))

;; the sweep of naive-kernel-arrays / the fold doorway, verbatim algebra
(define sweep
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (let ((rho (+ (array-sum (* (row x j) resid))
                       (* old (vector-ref xnorm j)))))
           (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                          (vector-ref xnorm j))))
             (vector-set! beta j bnew)
             (array-dec! resid (scale (- bnew old) (row x j)))))))))

(define derived (incrementalize sweep 'resid 'beta))
(unless derived (printf "NG: derivation refused\n") (exit 1))

;; growth beyond the dot: an invariant coefficient wraps the sum, and
;; the block must memoise whole -- the shape is nothing the old
;; recogniser knew
(define sweep-scaled
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (let ((rho (+ (* 0.5 (array-sum (* (row x j) resid)))
                       (* old (vector-ref xnorm j)))))
           (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                          (vector-ref xnorm j))))
             (vector-set! beta j bnew)
             (array-dec! resid (scale (- bnew old) (row x j)))))))))
(define derived-scaled (incrementalize sweep-scaled 'resid 'beta))
(unless derived-scaled
  (printf "NG: growth did not reach past the coefficient\n") (exit 1))

;; and the refusal: degree two in the scratch vector must not derive
(define sweep-nl
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((rho (array-sum (* resid resid))))
         (vector-set! beta j rho)
         (array-dec! resid (scale rho (row x j)))))))
(when (incrementalize sweep-nl 'resid 'beta)
  (printf "NG: a nonlinear context was accepted\n") (exit 1))

;; the linearity judgment on matrix- and tensor-shaped contexts: access
;; to the scratch tensor (a row, an element) is linear; two accesses
;; multiplied, or an index computed from it, are not
(for ([c (list (cons '(array-sum (* (row V k) w))                 1)
               (cons '(array-sum (* (row V k) (row V j)))         'nl)
               (cons '(array-ref V i j k)                         1)
               (cons '(vector-ref V (vector-ref V 0))             'nl)
               (cons '(scale (array-ref V 0 0) w)                 1)
               (cons '(scale (array-ref V 0 0) (row V j))         'nl)
               (cons '(* 0.5 (array-sum (* (row A k) (row V j)))) 1)
               (cons '(array-sum (* V V))                         'nl))])
  (unless (equal? (degree (car c) 'V) (cdr c))
    (printf "NG: degree misjudged ~s\n" (car c)) (exit 1)))

(define (program body)
  `((define (soft-threshold z g)
      (cond ((> z g) (- z g))
            ((< z (- 0.0 g)) (+ z g))
            (else 0.0)))
    (define (lasso x beta resid xnorm lam iters n p)
      (with-arrays ((x (p n)) (resid (n)))
        ,@body
        0))
    (define (main)
      (let ((n 4) (p 3) (iters 3)
            (x (vector 1.0 1.0 1.0 1.0
                       1.0 -1.0 1.0 -1.0
                       2.0 0.0 0.0 0.0))
            (beta (vector 0.0 0.0 0.0))
            (resid (vector 3.0 1.0 2.0 0.0))
            (xnorm (vector 4.0 4.0 4.0))
            (lam 0.25))
        (lasso x beta resid xnorm lam iters n p)
        (do ((j 0 (+ j 1))) ((= j p))
          (display (vector-ref beta j)) (display " "))
        (do ((i 0 (+ i 1))) ((= i n))
          (display (vector-ref resid i)) (display " "))
        (newline)))
    (main)))

(define naive-prog (program (list sweep)))
(define derived-prog (program (list derived)))

(define (run-oracle prog)
  (define f (make-temporary-file "inc~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define out (with-output-to-string
                (lambda ()
                  (system* (find-executable-path "racket")
                           "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  out)

(define naive-scaled-prog (program (list sweep-scaled)))
(define derived-scaled-prog (program (list derived-scaled)))

(define a (run-oracle naive-prog))
(define b (run-oracle derived-prog))
(define a2 (run-oracle naive-scaled-prog))
(define b2 (run-oracle derived-scaled-prog))
;; the derivation must really have hoisted the kernel: the derived
;; program contains a Gram fill (a sum of (row x)*(row x)) and no longer
;; reads resid inside the sweeps
(define derived-str (format "~s" derived))
(define gram-hoisted?
  (regexp-match? #rx"array-sum \\(\\* \\(row x k" derived-str))
;; inside the derived block, resid may appear only in the memo
;; initialisation and the final restoration -- the sweeps proper are free
;; of it. Two occurrences, no more.
(define sweep-free-of-resid?
  (= 2 (length (regexp-match* #rx"resid" derived-str))))

(cond
  [(not (equal? a b))
   (printf "NG: outputs differ\n  naive:   ~a  derived: ~a" a b) (exit 1)]
  [(not (equal? a2 b2))
   (printf "NG: scaled-context outputs differ\n  naive:   ~a  derived: ~a"
           a2 b2) (exit 1)]
  [(not gram-hoisted?)
   (printf "NG: no hoisted Gram kernel in the derived program\n") (exit 1)]
  [(not sweep-free-of-resid?)
   (printf "NG: the derived sweep still touches resid\n") (exit 1)]
  [else
   (printf "incremental: derived = naive (~a), Gram hoisted, sweep resid-free; scaled context and nonlinear refusal both behave\n"
           (string-trim a))
   (exit 0)])

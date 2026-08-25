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
               (cons '(array-sum (* V V))                         'nl)
               ;; reductions under other monoids: + passes linearity
               ;; through projections, * and max do not
               (cons '(array-reduce + 0.0 (sub V 0 2 0 2))        1)
               (cons '(array-reduce + 0.0 (slice V 0 2))          1)
               (cons '(array-reduce * 1.0 (slice V 0 2))          'nl)
               (cons '(array-reduce max 0.0 w)                    0))])
  (unless (equal? (degree (car c) 'V) (cdr c))
    (printf "NG: degree misjudged ~s\n" (car c)) (exit 1)))

;; matrix scratch: T tasks share one design matrix; resid is (T n),
;; read row-wise in the context and updated row-wise by row-dec!. The
;; memo comes out two-dimensional and the Gram kernel is shared across
;; tasks. No restoration exists for the matrix shape yet, so the
;; derivation demands the scratch verdict (restore? #f).
(define msweep
  '(range-for (t T)
     (range-for (sweep iters)
       (range-for (j p)
         (let ((old (vector-ref beta (+ (* t p) j))))
           (let ((rho (+ (array-sum (* (row x j) (row resid t)))
                         (* old (vector-ref xnorm j)))))
             (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                            (vector-ref xnorm j))))
               (vector-set! beta (+ (* t p) j) bnew)
               (row-dec! resid t (scale (- bnew old) (row x j))))))))))
(unless (incrementalize msweep 'resid 'beta #:restore? #f)
  (printf "NG: matrix-scratch derivation refused\n") (exit 1))
(when (incrementalize msweep 'resid 'beta)   ; restoration unsupported
  (printf "NG: matrix shape must refuse with restoration\n") (exit 1))

(define (mprogram body)
  `((define (soft-threshold z g)
      (cond ((> z g) (- z g))
            ((< z (- 0.0 g)) (+ z g))
            (else 0.0)))
    (define (mlasso x beta resid xnorm lam iters n p T)
      (with-arrays ((x (p n)) (resid (T n)))
        ,@body
        0))
    (define (main)
      (let ((n 4) (p 3) (iters 3) (T 2)
            (x (vector 1.0 1.0 1.0 1.0
                       1.0 -1.0 1.0 -1.0
                       2.0 0.0 0.0 0.0))
            (beta (make-vector 6 0.0))
            (resid (vector 3.0 1.0 2.0 0.0
                           1.0 -1.0 0.0 2.0))
            (xnorm (vector 4.0 4.0 4.0))
            (lam 0.25))
        (mlasso x beta resid xnorm lam iters n p T)
        (do ((k 0 (+ k 1))) ((= k 6))
          (display (vector-ref beta k)) (display " "))
        (newline)))
    (main)))
(define m-naive (mprogram (list msweep)))
(define m-derived
  (mprogram (list (incrementalize msweep 'resid 'beta #:restore? #f))))

;; the quadratic riding on the linear: the residual sum of squares
;; enters the penalty, a squared-norm read the catalog must carry --
;; the dot memo it needs is the one the linear machinery keeps anyway
(define sweep-rss
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (let ((rho (+ (array-sum (* (row x j) resid))
                       (* old (vector-ref xnorm j))))
               (rss (array-sum (* resid resid))))
           (let ((bnew (/ (soft-threshold rho
                                          (* lam (* (+ 1.0 (* 0.015625 rss))
                                                    (* 1.0 n))))
                          (vector-ref xnorm j))))
             (vector-set! beta j bnew)
             (array-dec! resid (scale (- bnew old) (row x j)))))))))
(define derived-rss (incrementalize sweep-rss 'resid 'beta))
(unless derived-rss
  (printf "NG: squared-norm context refused\n") (exit 1))


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
(define rss-naive (program (list sweep-rss)))
(define rss-derived (program (list derived-rss)))

;; the symmetry licence: a dot-shaped context reads its Gram by row
;; (first index the update coordinate), an asymmetric one must keep
;; the column read
(let ([d (format "~s" (incrementalize sweep 'resid 'beta))])
  (unless (regexp-match #rx"array-ref g[0-9]+ j k[0-9]+" d)
    (printf "NG: symmetric kernel not read by row\n") (exit 1))
  (when (regexp-match #rx"array-ref g[0-9]+ k[0-9]+ j\\)" d)
    (printf "NG: symmetric kernel still read by column\n") (exit 1)))
(define sweep-asym
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (let ((rho (+ (array-sum (* (row a j) resid))
                       (* old (vector-ref xnorm j)))))
           (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                          (vector-ref xnorm j))))
             (vector-set! beta j bnew)
             (array-dec! resid (scale (- bnew old) (row x j)))))))))
(let ([da (incrementalize sweep-asym 'resid 'beta)])
  (unless da (printf "NG: asymmetric context refused\n") (exit 1))
  (unless (regexp-match #rx"array-ref g[0-9]+ k[0-9]+ j\\)" (format "~s" da))
    (printf "NG: asymmetric kernel must read by column\n") (exit 1)))

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
(define a3 (run-oracle m-naive))
(define b3 (run-oracle m-derived))
(define a4 (run-oracle rss-naive))
(define b4 (run-oracle rss-derived))
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
  [(not (equal? a3 b3))
   (printf "NG: matrix-scratch outputs differ\n  naive:   ~a  derived: ~a"
           a3 b3) (exit 1)]
  [(not (equal? a4 b4))
   (printf "NG: squared-norm outputs differ\n  naive:   ~a  derived: ~a"
           a4 b4) (exit 1)]
  [(not gram-hoisted?)
   (printf "NG: no hoisted Gram kernel in the derived program\n") (exit 1)]
  [(not sweep-free-of-resid?)
   (printf "NG: the derived sweep still touches resid\n") (exit 1)]
  [else
   (printf "incremental: derived = naive (~a), Gram hoisted, sweep resid-free; scaled context and nonlinear refusal both behave\n"
           (string-trim a))
   (exit 0)])

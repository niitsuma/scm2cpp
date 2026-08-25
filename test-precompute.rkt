#lang racket
;;;; Units for the two standalone improvement rules: hoisting const
;;;; folds out of loops, and merging a table whose definition is an
;;;; index-restricted instance of a larger one.  Structural checks say
;;;; the rewrite really happened; the oracle runs say it changed
;;;; nothing observable.

(require (file "rewrite-precompute.scm"))

;; ---------------- rule 1: the hoist ----------------

;; a const dot inside a sweep: x and y untouched, j the only coordinate
(define loop1
  '(range-for (sweep iters)
     (range-for (j p)
       (vector-set! beta j
                    (+ (vector-ref beta j)
                       (* 0.1 (array-sum (* (row x j) y))))))))
(define h1 (precompute-const loop1))
(unless h1 (printf "NG: const dot not hoisted\n") (exit 1))
;; exactly one fold remains -- the build -- and the loop reads a table
(define (count-folds e)
  (length (regexp-match* #rx"array-sum" (format "~s" e))))
(unless (= 1 (count-folds h1))
  (printf "NG: expected one array-sum after hoist, got ~a\n"
          (count-folds h1))
  (exit 1))

;; maximality: an invariant coefficient hoists with the fold, but a
;; per-iteration scalar stops growth at the fold itself
(define loop1b
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (vector-set! beta j
                      (+ old (* old (array-sum (* (row x j) y)))))))))
(define c1b (const-candidates loop1b))
(unless (equal? c1b '((array-sum (* (row x j) y))))
  (printf "NG: growth misjudged around a per-iteration scalar: ~s\n" c1b)
  (exit 1))

;; refusal: the fold reads an array the loop writes
(define loop2
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((rho (array-sum (* (row x j) resid))))
         (vector-set! beta j rho)
         (array-dec! resid (scale rho (row x j)))))))
(when (precompute-const loop2)
  (printf "NG: a fold over a written array was hoisted\n") (exit 1))

;; refusal: a per-iteration scalar inside the fold admits nothing
(define loop3
  '(range-for (sweep iters)
     (range-for (j p)
       (let ((old (vector-ref beta j)))
         (vector-set! beta j (array-sum (scale old (row x j))))))))
(when (precompute-const loop3)
  (printf "NG: a fold over a rebound scalar was hoisted\n") (exit 1))

;; the cost gate: a fold that is a table build already -- its only
;; enclosing coordinate is its own axis -- must not re-hoist, or the
;; rule would hoist its own emissions forever
(define fill-like
  '(range-for (k p)
     (vector-set! c k (array-sum (* (row x k) y)))))
(when (precompute-const fill-like)
  (printf "NG: a table build was re-hoisted\n") (exit 1))

;; a zero-coordinate fold is classic loop-invariant motion
(define loop4
  '(range-for (sweep iters)
     (range-for (j p)
       (vector-set! beta j (array-sum (* y y))))))
(define h4 (precompute-const loop4))
(unless (and h4 (match h4
                  [`(let ((,_ (array-sum (* y y)))) ,_ ...) #t]
                  [_ #f]))
  (printf "NG: scalar fold not hoisted to a let: ~s\n" h4)
  (exit 1))

;; ---------------- rule 2: the merge ----------------

(define defs
  '((g (k1 k2) (array-sum (* (row x k1) (row x k2))))
    (xnorm (j) (array-sum (* (row x j) (row x j))))))
(define plan (table-subset-plan defs))
(unless (equal? plan '((xnorm g ((k1 . j) (k2 . j)))))
  (printf "NG: diagonal subset not found: ~s\n" plan) (exit 1))

;; a different base array must not merge
(define defs2
  '((g (k1 k2) (array-sum (* (row x k1) (row x k2))))
    (znorm (j) (array-sum (* (row z j) (row z j))))))
(unless (null? (table-subset-plan defs2))
  (printf "NG: merged across distinct base arrays\n") (exit 1))

;; the absorber itself stays: no chain merges away the big table
(define defs3
  '((g (k1 k2) (array-sum (* (row x k1) (row x k2))))
    (g2 (a b) (array-sum (* (row x a) (row x b))))
    (xnorm (j) (array-sum (* (row x j) (row x j))))))
(let ([p3 (table-subset-plan defs3)])
  (for ([m p3])
    (when (memq (car m) (map cadr p3))
      (printf "NG: an absorber was merged away: ~s\n" p3) (exit 1))))

(define body
  '(range-for (j p)
     (vector-set! out j (* 2.0 (vector-ref xnorm j)))))
(define merged (apply-table-merge body plan defs))
(unless (equal? merged
                '(range-for (j p)
                   (vector-set! out j (* 2.0 (array-ref g j j)))))
  (printf "NG: read rewrite wrong: ~s\n" merged) (exit 1))

;; ---------------- rule: dead fills ----------------

(define chain
  '((range-for (i n) (vector-set! a i (* (vector-ref y i) 2.0)))
    (range-for (i n) (vector-set! b i (+ (vector-ref a i) 1.0)))
    (range-for (i n) (vector-set! out i (vector-ref y i)))
    (display (vector-ref out 0))))
;; b is read by nothing; a is still read by b's fill; out is displayed
(unless (equal? (dead-fill-plan chain '()) '(b))
  (printf "NG: dead plan ~s\n" (dead-fill-plan chain '())) (exit 1))
;; with b's fill gone, a dies in the next round
(define chain2 (list (car chain) 0 (caddr chain) (cadddr chain)))
(unless (equal? (dead-fill-plan chain2 '()) '(a))
  (printf "NG: chained death missed\n") (exit 1))
;; an impure fill is not removable however unread its target
(unless (null? (dead-fill-plan
                '((range-for (i n)
                    (vector-set! z i (begin (set! g 1) 0.0))))
                '()))
  (printf "NG: impure fill declared dead\n") (exit 1))
;; a live-out array is the caller's to read: never a candidate
(unless (null? (dead-fill-plan
                '((range-for (i n) (vector-set! outv i 1.0)))
                '(outv)))
  (printf "NG: live-out fill declared dead\n") (exit 1))

;; ---------------- oracle: nothing observable moved ----------------

(define (run-oracle prog)
  (define f (make-temporary-file "pre~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define out (with-output-to-string
                (lambda ()
                  (system* (find-executable-path "racket")
                           "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  out)

;; the hoist: same numbers before and after
(define (hoist-prog body)
  `((define (kern x y beta iters p n)
      (with-arrays ((x (p n)) (y (n)))
        ,body
        0))
    (define (main)
      (let ((p 3) (n 4) (iters 2)
            (x (vector 1.0 2.0 0.0 1.0
                       0.5 -1.0 1.0 0.0
                       2.0 0.0 0.5 -1.0))
            (y (vector 1.0 -1.0 2.0 0.5))
            (beta (make-vector 3 0.0)))
        (kern x y beta iters 3 4)
        (do ((k 0 (+ k 1))) ((= k 3))
          (display (vector-ref beta k)) (display " "))
        (newline)))
    (main)))
(let ([a (run-oracle (hoist-prog loop1))]
      [b (run-oracle (hoist-prog h1))])
  (unless (and (equal? a b) (regexp-match #rx"[0-9]" a))
    (printf "NG: hoist changed output: ~s vs ~s\n" a b) (exit 1)))

;; the merge: kern reads xnorm before, the Gram diagonal after; main
;; builds both tables so the two programs differ only in the read
(define (merge-prog body)
  `((define (kern g xnorm out p)
      (with-arrays ((g (p p)))
        ,body
        0))
    (define (main)
      (let ((p 3) (n 4)
            (x (vector 1.0 2.0 0.0 1.0
                       0.5 -1.0 1.0 0.0
                       2.0 0.0 0.5 -1.0))
            (g (make-vector 9 0.0))
            (xnorm (make-vector 3 0.0))
            (out (make-vector 3 0.0)))
        (with-arrays ((x (p n)) (g (p p)))
          (range-for (k1 p)
            (range-for (k2 p)
              (array-set! g k1 k2
                          (array-sum (* (row x k1) (row x k2))))))
          (range-for (j p)
            (vector-set! xnorm j
                         (array-sum (* (row x j) (row x j))))))
        (kern g xnorm out 3)
        (do ((k 0 (+ k 1))) ((= k 3))
          (display (vector-ref out k)) (display " "))
        (newline)))
    (main)))
(let ([a (run-oracle (merge-prog body))]
      [b (run-oracle (merge-prog merged))])
  (unless (and (equal? a b) (regexp-match #rx"[0-9]" a))
    (printf "NG: merge changed output: ~s vs ~s\n" a b) (exit 1)))

(printf "PASS precompute-unit\n")

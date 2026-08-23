#lang racket
;;;; Units for the normalization pass: fill-loop definitions are found,
;;;; row reads inline to slice views, distribution exposes the four
;;;; lag sums of the Gram element, refusals refuse, and the oracle
;;;; confirms the normalized fold computes the naive numbers.

(require (file "rewrite-normalize.scm")
         (only-in (file "rewrite-incremental.scm") walk-collect))

;; the moving-average fill, in the fold layer's own words
(define fill
  '(range-for (w p)
     (range-for (i nobs)
       (array-set! xd w i
                   (/ (- (vector-ref ps (+ wmax i))
                         (vector-ref ps (- (+ wmax i) (+ w 1))))
                      (* 1.0 (+ w 1)))))))
(define defs (collect-fill-defs (list fill)))
(unless (and (= 1 (length defs)) (eq? 'xd (caar defs)))
  (printf "NG: fill definition not collected: ~s\n" defs) (exit 1))

;; a rank-1 fill and a rejected impure fill
(define more
  (collect-fill-defs
   '((range-for (t n) (vector-set! q t (* (vector-ref ps t) 2.0)))
     (range-for (t n) (vector-set! r t (begin (set! z 1) 0.0))))))
(unless (equal? (map car more) '(q))
  (printf "NG: rank-1/impure fills misjudged: ~s\n" (map car more))
  (exit 1))

;; the Gram element: four lag sums over slices of ps, nothing else
(define norm (inline-normalize '(array-sum (* (row xd j) (row xd k))) defs))
(unless norm (printf "NG: gram element refused\n") (exit 1))
(define sums
  (walk-collect (lambda (x) (and (pair? x) (eq? (car x) 'array-sum))) norm))
(unless (and (= 4 (length sums))
             (for/and ([s sums])
               (match s
                 [`(array-sum (* (slice ps ,_ ,_) (slice ps ,_ ,_))) #t]
                 [_ #f])))
  (printf "NG: expected four slice-product sums: ~s\n" sums) (exit 1))

;; refusals: a stretched index and a negated index have no slice view
(for ([bad '((vector-ref ps (* 2 i)) (vector-ref ps (- wmax i)))])
  (let ([d (list (list 'xb '(w i) '(p nobs) bad))])
    (when (inline-normalize '(array-sum (* (row xb j) (row xb k))) d)
      (printf "NG: unviewable index accepted: ~s\n" bad) (exit 1))))

;; scalar reads substitute directly, nonlinear elements included
(define d2 '((qq (t) (n) (* (vector-ref ps t) (vector-ref ps t)))))
(unless (equal? (inline-normalize '(+ 1.0 (vector-ref qq a)) d2)
                '(+ 1.0 (* (vector-ref ps a) (vector-ref ps a))))
  (printf "NG: scalar inline wrong\n") (exit 1))

;; ---------------- oracle: naive against normalized ----------------

(define (run-oracle prog)
  (define f (make-temporary-file "nrm~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define out (with-output-to-string
                (lambda ()
                  (system* (find-executable-path "racket")
                           "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  out)

(define prog
  `((define (main)
      (let ((wmax 3) (nobs 4) (p 3) (n 8)
            (ps (vector 0.0 1.0 3.0 4.0 8.0 9.0 13.0 15.0))
            (xd (make-vector 12 0.0))
            (g1 (make-vector 9 0.0))
            (g2 (make-vector 9 0.0)))
        (with-arrays ((ps (n)) (xd (p nobs)) (g1 (p p)) (g2 (p p)))
          ,fill
          (range-for (j p)
            (range-for (k p)
              (array-set! g1 j k
                          (array-sum (* (row xd j) (row xd k))))))
          (range-for (j p)
            (range-for (k p)
              (array-set! g2 j k ,norm))))
        (do ((t 0 (+ t 1))) ((= t 9))
          (display (vector-ref g1 t)) (display " "))
        (newline)
        (do ((t 0 (+ t 1))) ((= t 9))
          (display (vector-ref g2 t)) (display " "))
        (newline)))
    (main)))
(define out (run-oracle prog))
;; the oracle runs the program once per doorway, so the naive and
;; normalized lines arrive in pairs; every pair must agree
(define lines (filter non-empty-string? (string-split out "\n")))
(unless (and (even? (length lines)) (>= (length lines) 2))
  (printf "NG: oracle output malformed: ~s\n" out) (exit 1))
(define (nums l) (map string->number (string-split l)))
(let loop ([ls lines])
  (unless (null? ls)
    (let ([a (nums (car ls))] [b (nums (cadr ls))])
      (unless (and (= 9 (length a)) (andmap number? a) (andmap number? b)
                   (for/and ([x a] [y b])
                     (< (abs (- x y)) (* 1e-9 (max 1.0 (abs x))))))
        (printf "NG: normalized fold moved a number:\n~a" out) (exit 1)))
    (loop (cddr ls))))

(printf "PASS normalize-unit\n")

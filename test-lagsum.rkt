#lang racket
;;;; Units for the lag-family lowering: the four slice-product sums of
;;;; the normalized Gram element become two-point reads of one
;;;; lag-indexed prefix table, refusals refuse, and the oracle confirms
;;;; the lowered program computes the naive numbers.

(require (file "rewrite-normalize.scm")
         (file "rewrite-lagsum.scm"))

(define fill
  '(range-for (w p)
     (range-for (i nobs)
       (array-set! xd w i
                   (/ (- (vector-ref ps (+ wmax i))
                         (vector-ref ps (- (+ wmax i) (+ w 1))))
                      (* 1.0 (+ w 1)))))))
(define defs (collect-fill-defs (list fill)))
(define norm (inline-normalize '(array-sum (* (row xd j) (row xd k)))
                               defs))
(unless norm (printf "NG: normalization refused\n") (exit 1))

(unless (= 4 (length (lag-terms norm)))
  (printf "NG: expected four lag terms\n") (exit 1))

(define low (lag-lower norm '((ps . n)) '((j . p) (k . p))))
(unless low (printf "NG: lowering refused\n") (exit 1))
(match-define (list decl build rewritten) low)

;; the lag axis covers [-p, p]: 2p+1 rows
(unless (equal? (car (cadr decl)) '(+ (* 2 p) 1))
  (printf "NG: lag extent wrong: ~s\n" decl) (exit 1))
;; no fold survives in the rewritten expression
(when (regexp-match #rx"array-sum" (format "~s" rewritten))
  (printf "NG: a fold survived the lowering\n") (exit 1))

;; mixed bases are one family per (V, W) pair: the c-initialization
;; shape (slice of ps against a window of y) lowers to a lag table
;; whose guard is the second base's own extent
(define mixed
  '(- (array-sum (* (slice ps wmax (+ wmax nobs)) (slice y 0 (+ 0 nobs))))
      (array-sum (* (slice ps (- wmax (+ k 1)) (+ (- wmax (+ k 1)) nobs))
                    (slice y 0 (+ 0 nobs))))))
(define mlow (lag-lower mixed '((ps . n) (y . nobs)) '((k . p))))
(unless mlow (printf "NG: mixed pair refused\n") (exit 1))
(unless (regexp-match #rx"vector-ref y" (format "~s" (cadr mlow)))
  (printf "NG: mixed build does not read the second base\n") (exit 1))
(unless (regexp-match #rx"nobs" (format "~s" (cadr mlow)))
  (printf "NG: mixed guard ignores the second extent\n") (exit 1))

;; refusals: two different pairs in one expression share no table;
;; unequal window lengths are not one family
(when (lag-lower '(+ (array-sum (* (slice ps 0 4) (slice qs 0 4)))
                     (array-sum (* (slice ps 0 4) (slice zs 0 4))))
                 '((ps . n) (qs . n) (zs . n)) '())
  (printf "NG: two pairs lowered onto one table\n") (exit 1))
(unless (null? (lag-terms '(array-sum (* (slice ps 0 4) (slice ps 1 4)))))
  (printf "NG: unequal windows made a term\n") (exit 1))

;; ---------------- oracle: naive against lowered ----------------

(define (run-oracle prog)
  (define f (make-temporary-file "lag~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define out (with-output-to-string
                (lambda ()
                  (system* (find-executable-path "racket")
                           "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  out)

(define cs (car decl))
(define prog
  `((define (main)
      (let ((wmax 3) (nobs 4) (p 3) (n 8)
            (ps (vector 0.0 1.0 3.0 4.0 8.0 9.0 13.0 15.0))
            (xd (make-vector 12 0.0))
            (g1 (make-vector 9 0.0))
            (g3 (make-vector 9 0.0))
            (,cs (make-vector (* (+ (* 2 3) 1) (+ 8 1)) 0.0)))
        (with-arrays ((ps (n)) (xd (p nobs)) (g1 (p p)) (g3 (p p))
                      (,cs ,(cadr decl)))
          ,fill
          (range-for (j p)
            (range-for (k p)
              (array-set! g1 j k
                          (array-sum (* (row xd j) (row xd k))))))
          ,build
          (range-for (j p)
            (range-for (k p)
              (array-set! g3 j k ,rewritten))))
        (do ((t 0 (+ t 1))) ((= t 9))
          (display (vector-ref g1 t)) (display " "))
        (newline)
        (do ((t 0 (+ t 1))) ((= t 9))
          (display (vector-ref g3 t)) (display " "))
        (newline)))
    (main)))
(define out (run-oracle prog))
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
        (printf "NG: lowering moved a number:\n~a" out) (exit 1)))
    (loop (cddr ls))))

(printf "PASS lagsum-unit\n")

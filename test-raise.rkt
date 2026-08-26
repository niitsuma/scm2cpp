#lang racket
;;;; Units for loop raising: each rule lifts exactly its inverse
;;;; expansion, the refusals refuse, and a lasso written in plain
;;;; Scheme -- do loops, vector-set!, flat indices -- derives all the
;;;; way to the covariance kernel and prints the naive numbers.

(require (file "rewrite-raise.scm")
         (file "rewrite-driver.scm"))

(define dims '((x (p nobs))))
(define exts '((ps . n) (y . nobs) (resid . nobs)))

;; R1 + R4: a self-update loop in do form
(define upd
  '((do ((i 0 (+ i 1))) ((= i n))
      (vector-set! r i (- (vector-ref r i) (* d (vector-ref s i)))))))
(unless (equal? (raise-loops upd '() '((r . n) (s . n)))
                '((array-dec! r (scale d s))))
  (printf "NG: update not raised: ~s\n" (raise-loops upd '() '((r . n) (s . n))))
  (exit 1))

;; R3 + R2: accumulation over a flat row
(define acc
  '((do ((i 0 (+ i 1))) ((= i n))
      (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                          (vector-ref w i)))))))
(unless (equal? (raise-loops acc '((x (p n))) '((w . n)))
                '((set! rho (+ rho (array-sum (* (row x j) w))))))
  (printf "NG: accumulation not raised: ~s\n"
          (raise-loops acc '((x (p n))) '((w . n))))
  (exit 1))

;; refusals: a stride the algebra has no word for; a self-referencing
;; term; an accumulator whose seed is not the fold's zero
;; the do still becomes range-for, but no vector operation may appear
(let ([r (raise-loops
          '((do ((i 0 (+ i 1))) ((= i n))
              (vector-set! r i (- (vector-ref r i)
                                  (vector-ref s (* 2 i))))))
          '() '((r . n) (s . n)))])
  (when (and r (regexp-match #rx"array-dec!" (format "~s" r)))
    (printf "NG: strided read raised\n") (exit 1)))
(let ([r (raise-loops
          '((do ((i 0 (+ i 1))) ((= i n))
              (vector-set! r i (- (vector-ref r i)
                                  (vector-ref r (+ i 1))))))
          '() '((r . n)))])
  (when (and r (regexp-match #rx"array-dec!" (format "~s" r)))
    (printf "NG: self-referencing update raised\n") (exit 1)))
(unless (equal? (raise-loops
                 '((let ((acc 1.0))
                     (set! acc (+ acc (array-sum v)))
                     (display acc)))
                 '() '())
                #f)
  (printf "NG: a nonzero seed folded into its binding\n") (exit 1))

;; ---- the whole road: plain Scheme to the covariance kernel ----

(define raw
  '((do ((w 0 (+ w 1))) ((= w p))
      (do ((i 0 (+ i 1))) ((= i nobs))
        (vector-set! x (+ (* w nobs) i)
                     (/ (- (vector-ref ps (+ wmax i))
                           (vector-ref ps (- (+ wmax i) (+ w 1))))
                        (* 1.0 (+ w 1))))))
    (do ((jj 0 (+ jj 1))) ((= jj p))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i nobs))
          (set! acc (+ acc (* (vector-ref x (+ (* jj nobs) i))
                              (vector-ref x (+ (* jj nobs) i))))))
        (vector-set! xnorm jj acc)))
    (do ((i 0 (+ i 1))) ((= i nobs))
      (vector-set! resid i (vector-ref y i)))
    (do ((sweep 0 (+ sweep 1))) ((= sweep iters))
      (do ((j 0 (+ j 1))) ((= j p))
        (let ((rho 0.0)
              (old (vector-ref beta j)))
          (do ((i 0 (+ i 1))) ((= i nobs))
            (set! rho (+ rho (* (vector-ref x (+ (* j nobs) i))
                                (vector-ref resid i)))))
          (set! rho (+ rho (* old (vector-ref xnorm j))))
          (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 nobs)))
                         (vector-ref xnorm j))))
            (vector-set! beta j bnew)
            (do ((i 0 (+ i 1))) ((= i nobs))
              (vector-set! resid i
                           (- (vector-ref resid i)
                              (* (- bnew old)
                                 (vector-ref x (+ (* j nobs) i))))))))))))

(define-values (derived log)
  (derive-fixpoint/log raw 'resid 'beta #:restore? 'auto
                       #:extents exts #:dims dims))
(unless (equal? log
                '(raise differencing merge lower lower precompute dead-fill))
  (printf "NG: raw firing log ~s\n" log) (exit 1))
(define ds (format "~s" derived))
(when (regexp-match #rx"row x |array-set! x |vector-ref xnorm" ds)
  (printf "NG: raw chain left the design matrix or the norms\n") (exit 1))
(unless (= 0 (length (regexp-match* #rx"array-sum" ds)))
  (printf "NG: a fold survived the raw chain\n") (exit 1))

;; and the numbers: the raw program against its derivation
(define (run-oracle prog)
  (define f (make-temporary-file "rse~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define o (with-output-to-string
              (lambda ()
                (system* (find-executable-path "racket")
                         "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  o)

(define (program body)
  `((define (soft-threshold z g)
      (cond ((> z g) (- z g))
            ((< z (- 0.0 g)) (+ z g))
            (else 0.0)))
    (define (main)
      (let ((wmax 3) (nobs 4) (p 3) (n 8) (iters 3) (lam 0.05)
            (ps (vector 0.0 1.0 3.0 4.0 8.0 9.0 13.0 15.0))
            (y (vector 1.0 -1.0 2.0 0.5))
            (x (make-vector 12 0.0))
            (xnorm (make-vector 3 0.0))
            (resid (make-vector 4 0.0))
            (beta (make-vector 3 0.0)))
        (with-arrays ((ps (n)) (x (p nobs)) (resid (nobs)))
          ,@body
          0)
        (do ((t 0 (+ t 1))) ((= t 3))
          (display (vector-ref beta t)) (display " "))
        (newline)))
    (main)))
(define (nums s) (map string->number (string-split s)))
(define (close? a b)
  (and (= (length a) (length b)) (andmap number? a) (andmap number? b)
       (for/and ([u a] [v b])
         (< (abs (- u v)) (* 1e-9 (max 1.0 (abs u)))))))
(let ([a (filter non-empty-string?
                 (string-split (run-oracle (program raw)) "\n"))]
      [b (filter non-empty-string?
                 (string-split (run-oracle (program derived)) "\n"))])
  (unless (and (pair? a) (= (length a) (length b))
               (for/and ([u a] [v b]) (close? (nums u) (nums v))))
    (printf "NG: raw derivation moved a number\n~s\n~s\n" a b) (exit 1)))

(printf "PASS raise-unit\n")

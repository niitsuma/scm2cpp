#lang racket
;;;; End to end: a naive moving-average lasso, written with no
;;;; knowledge of the covariance update, runs through the fixpoint
;;;; driver.  Differencing produces the memo and the Gram kernel, the
;;;; subset merge folds the column norms into the Gram diagonal, and
;;;; normalization plus lag lowering turn the Gram build into the
;;;; lag-indexed prefix table of the hand-written covariance kernel.
;;;; The derived program must print the naive numbers -- through the
;;;; Racket oracle and through the actual C++ it translates to.

(require (file "rewrite-driver.scm"))

;; every rule of the driver is reachable: a program whose only
;; redundancy is a const fold re-evaluated across sweeps -- nothing to
;; difference, merge or lower -- is carried by the precompute rule
;; alone, and by it exactly once
(let-values ([(out log)
              (derive-fixpoint/log
               '((range-for (sweep iters)
                   (range-for (j p)
                     (vector-set! beta j
                                  (+ (vector-ref beta j)
                                     (* 0.1 (array-sum (* (row x j) y))))))))
               'resid 'beta)])
  (unless (equal? log '(precompute))
    (printf "NG: expected one precompute firing, got ~s\n" log) (exit 1)))

(define stmts
  '((range-for (w p)
      (range-for (i nobs)
        (array-set! x w i (/ (- (vector-ref ps (+ wmax i))
                                (vector-ref ps (- (+ wmax i) (+ w 1))))
                             (* 1.0 (+ w 1))))))
    (range-for (j p)
      (vector-set! xnorm j (array-sum (* (row x j) (row x j)))))
    (range-for (i nobs)
      (vector-set! resid i (vector-ref y i)))
    (range-for (sweep iters)
      (range-for (j p)
        (let ((old (vector-ref beta j)))
          (let ((rho (+ (array-sum (* (row x j) resid))
                        (* old (vector-ref xnorm j)))))
            (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 nobs)))
                           (vector-ref xnorm j))))
              (vector-set! beta j bnew)
              (array-dec! resid (scale (- bnew old) (row x j))))))))))

(define-values (derived firing-log)
  (derive-fixpoint/log stmts 'resid 'beta #:restore? #f
                       #:extents '((ps . n))))

;; three rules carried the covariance derivation, once each, in this
;; order; the precompute rule had nothing left to do -- differencing
;; hoists its own kernel, and every remaining fold is a table build
;; its cost gate refuses
(unless (equal? firing-log '(differencing merge lower))
  (printf "NG: firing log ~s\n" firing-log) (exit 1))

;; the three firings, visible in the result: no read of the small
;; table, one surviving fold (the memo initialization, whose mixed
;; bases rightly refuse the lowering), and a lag-guarded prefix build
(define ds (format "~s" derived))
(unless (not (regexp-match #rx"vector-ref xnorm" ds))
  (printf "NG: column norms not merged into the Gram diagonal\n") (exit 1))
(unless (= 1 (length (regexp-match* #rx"array-sum" ds)))
  (printf "NG: expected exactly the memo fold to survive\n") (exit 1))
(unless (regexp-match #rx"range-for \\(dd" ds)
  (printf "NG: no lag build emitted\n") (exit 1))

;; ---------------- the program pair ----------------

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

(define naive-prog (program stmts))
(define derived-prog (program derived))

(define (run-oracle prog)
  (define f (make-temporary-file "drv~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define out (with-output-to-string
                (lambda ()
                  (system* (find-executable-path "racket")
                           "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  out)

(define (nums s) (map string->number (string-split s)))
(define (close? a b)
  (and (= (length a) (length b)) (andmap number? a) (andmap number? b)
       (for/and ([x a] [y b])
         (< (abs (- x y)) (* 1e-9 (max 1.0 (abs x)))))))

(define naive-lines
  (filter non-empty-string? (string-split (run-oracle naive-prog) "\n")))
(define derived-lines
  (filter non-empty-string? (string-split (run-oracle derived-prog) "\n")))
(unless (and (pair? naive-lines)
             (= (length naive-lines) (length derived-lines))
             (for/and ([a naive-lines] [b derived-lines])
               (close? (nums a) (nums b))))
  (printf "NG: derived program moved a number under the oracle\n~s\n~s\n"
          naive-lines derived-lines)
  (exit 1))

;; ---------------- and through the translator ----------------

;; the translator subprocess needs the bundled cKanren when the
;; caller has not registered one -- the same fallback run-tests.sh uses
(unless (getenv "PLTCOLLECTS")
  (putenv "PLTCOLLECTS" (format "~a/vendor:" (current-directory))))

(define workdir (make-temporary-directory "drvcpp~a"))
(define scmfile (build-path workdir "derived.scm"))
;; the oracle program ends with a top-level (main) call; the translator
;; emits that call itself, so the translated source must not carry it
(with-output-to-file scmfile
  (lambda () (for ([s derived-prog]
                   #:unless (equal? s '(main)))
               (writeln s))))
(unless (system* (find-executable-path "racket")
                 "scm2cpp-file.scm" "-t" "scm2c.typ" (path->string scmfile))
  (printf "NG: translation failed\n") (exit 1))
(define cppfile (build-path workdir "derived.cpp"))
;; the .cpp only includes the header; the generated code is the .hpp
(define cpp (file->string (build-path workdir "derived.hpp")))
;; the lag build made it into the C++: a guarded product accumulating
;; into a prefix row, and no O(n p^2) Gram fold anywhere
(unless (regexp-match #rx"cs[0-9]+" cpp)
  (printf "NG: no lag table in the C++\n") (exit 1))
(define exe (build-path workdir "derived.exe"))
(unless (system (format "g++ -O2 -std=c++17 -I~a -include boost/operators.hpp -include boost/optional.hpp -o ~a ~a"
                        (current-directory) exe cppfile))
  (printf "NG: C++ compile failed\n") (exit 1))
(define cppout (with-output-to-string (lambda () (system* exe))))
;; the executable prints at cout's own precision; the suite's numeric
;; diff is the arbiter of whether that matches the oracle, so it is
;; the arbiter here too
(define ofile (build-path workdir "oracle.txt"))
(define cfile (build-path workdir "cpp.txt"))
;; the oracle ran the program once per doorway; the executable ran
;; once, so one doorway's line is the reference
(with-output-to-file ofile
  (lambda () (display (car naive-lines)) (newline)))
(with-output-to-file cfile (lambda () (display cppout)))
(unless (system* (find-executable-path "racket")
                 "test-oracle.rkt" "diff"
                 (path->string ofile) (path->string cfile))
  (printf "NG: C++ output differs\n~s\n~s\n" naive-lines cppout)
  (exit 1))
(delete-directory/files workdir)

(printf "PASS derive-unit\n")

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
                       #:extents '((ps . n) (y . nobs))))

;; the full chain: differencing makes the memo and the Gram; the
;; merge folds the norms into the diagonal; the Gram build lowers to
;; its lag table; the memo initialization lowers to the mixed-base
;; (ps, y) table -- accepted speculatively because it leaves the
;; design matrix unread -- and the dead-fill round then collects the
;; design matrix, the residual copy and the restoration snapshot
;; the precompute firing is the inverse-factor hoist: the lowered
;; Gram element's divisions become two table reads
(unless (equal? firing-log
                '(differencing merge lower lower precompute dead-fill))
  (printf "NG: firing log ~s\n" firing-log) (exit 1))

;; the three firings, visible in the result: no read of the small
;; table, one surviving fold (the memo initialization, whose mixed
;; bases rightly refuse the lowering), and a lag-guarded prefix build
(define ds (format "~s" derived))
(unless (not (regexp-match #rx"vector-ref xnorm" ds))
  (printf "NG: column norms not merged into the Gram diagonal\n") (exit 1))
(unless (= 0 (length (regexp-match* #rx"array-sum" ds)))
  (printf "NG: a fold survived the full chain\n") (exit 1))
(unless (= 2 (length (regexp-match* #rx"range-for \\(dd" ds)))
  (printf "NG: expected the (ps ps) and (ps y) lag builds\n") (exit 1))
;; the derived program computes without the design matrix at all
(unless (not (regexp-match #rx"row x |array-set! x " ds))
  (printf "NG: the design matrix survived\n") (exit 1))

;; the merge comparison runs modulo normalization: the same norms
;; written through the other doorway -- array-dot instead of a summed
;; product -- must still fold into the Gram diagonal
(let ([stmts2 (for/list ([s stmts])
                (match s
                  [`(range-for (j p) (vector-set! xnorm j ,_))
                   '(range-for (j p)
                      (vector-set! xnorm j
                                   (array-dot (row x j) (row x j))))]
                  [_ s]))])
  (let-values ([(out2 log2)
                (derive-fixpoint/log stmts2 'resid 'beta #:restore? #f
                                     #:extents '((ps . n) (y . nobs)))])
    (unless (equal? log2
                    '(differencing merge lower lower precompute dead-fill))
      (printf "NG: dot-doorway firing log ~s\n" log2) (exit 1))
    (when (regexp-match #rx"vector-ref xnorm" (format "~s" out2))
      (printf "NG: dot-doorway norms not merged\n") (exit 1))))

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

;; ---- the local-scratch shape: is the liveness machinery needed? ----

;; When resid and xnorm are declared and initialized at the head of
;; the kernel itself, scratch-ness is a syntactic fact of the
;; statement list: nothing after the sweep reads resid.  'auto
;; licenses the restore-elision from that fact alone -- the
;; parameter-liveness pass and the internalization pass never run.
(let-values ([(d log) (derive-fixpoint/log stmts 'resid 'beta
                                           #:restore? 'auto
                                           #:extents '((ps . n) (y . nobs)))])
  (unless (equal? log
                  '(differencing merge lower lower precompute dead-fill))
    (printf "NG: auto firing log ~s\n" log) (exit 1))
  (when (regexp-match #rx"array-dec! resid" (format "~s" d))
    (printf "NG: auto emitted a restoration for a dead scratch\n") (exit 1)))

;; a later read of the scratch forces the restoration back on, and
;; the restored values are the naive ones
(define stmts-observed
  (append stmts '((display (vector-ref resid 0)) (newline))))
;; with the scratch observed, restoration keeps the design matrix
;; alive, so the speculative memo lowering finds nothing newly dead
;; and rolls back: the memo fold stays, and so does x
(define-values (d-obs log-obs)
  (derive-fixpoint/log stmts-observed 'resid 'beta
                       #:restore? 'auto #:extents '((ps . n) (y . nobs))))
(unless (equal? log-obs '(differencing merge lower precompute))
  (printf "NG: observed firing log ~s\n" log-obs) (exit 1))
(unless (member '(display (vector-ref resid 0)) d-obs)
  (printf "NG: observed read vanished\n") (exit 1))
(unless (regexp-match #rx"array-dec! resid" (format "~s" d-obs))
  (printf "NG: observed scratch lost its restoration\n") (exit 1))
(let ([a (filter non-empty-string?
                 (string-split (run-oracle (program stmts-observed)) "\n"))]
      [b (filter non-empty-string?
                 (string-split (run-oracle (program d-obs)) "\n"))])
  (unless (and (pair? a) (= (length a) (length b))
               (for/and ([x a] [y b]) (close? (nums x) (nums y))))
    (printf "NG: restoration moved a number\n~s\n~s\n" a b) (exit 1)))

;; the function boundary: with the design matrix built outside the
;; derived scope, the lag lowering has no definition to inline --
;; differencing and merge still carry, the Gram build stays naive.
;; Localizing the scratch is free; severing the definition of x from
;; the kernel is not.
(let-values ([(d log) (derive-fixpoint/log (cdr stmts) 'resid 'beta
                                           #:restore? 'auto
                                           #:extents '((ps . n) (y . nobs)))])
  (unless (equal? log '(differencing merge dead-fill))
    (printf "NG: boundary firing log ~s\n" log) (exit 1)))

;; dead fills chain through the driver: the unread table goes first,
;; then the table only it was reading
(let-values ([(d log)
              (derive-fixpoint/log
               '((range-for (i n) (vector-set! aa i (* (vector-ref y i) 2.0)))
                 (range-for (i n) (vector-set! bb i (+ (vector-ref aa i) 1.0)))
                 (range-for (i n) (vector-set! outv i (vector-ref y i)))
                 (display (vector-ref outv 0)))
               'resid 'beta)])
  (unless (equal? log '(dead-fill dead-fill))
    (printf "NG: chain firing log ~s\n" log) (exit 1))
  (when (regexp-match #rx"vector-set! aa|vector-set! bb" (format "~s" d))
    (printf "NG: dead fills survived the chain\n") (exit 1)))

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
;; a numeric kernel earns the minimal runtime: the define is present,
;; no generated line says boost, and the compile below carries none of
;; the forced boost includes the full profile needs
(unless (regexp-match #rx"SCM2CPP_MINIMAL" cpp)
  (printf "NG: kernel not given the minimal runtime\n") (exit 1))
(when (regexp-match #rx"boost" cpp)
  (printf "NG: boost text in a minimal kernel\n") (exit 1))
(define exe (build-path workdir "derived.exe"))
(unless (system (format "g++ -O2 -std=c++17 -I~a -o ~a ~a"
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

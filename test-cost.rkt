#lang racket
;;;; Units for the unified cost model: the polynomial algebra, the
;;;; deliberately partial symbolic order, numeric evaluation, and the
;;;; covariance derivation costed end to end -- the model must call
;;;; the derived program an order of magnitude cheaper at benchmark
;;;; sizes, and the driver must reach the same firing sequence when
;;;; the speculative licence is decided by sizes instead of the
;;;; enabling test.

(require (file "rewrite-cost.scm")
         (file "rewrite-driver.scm"))

;; the symbolic order: comparable where domination is provable,
;; silent where it is not
(define pn (expr->poly '(* p n)))
(unless (and (poly<? pn (expr->poly '(* 2 (* p n))))
             (not (poly<=? (expr->poly '(* 2 (* p n))) pn)))
  (printf "NG: pn against 2pn misjudged\n") (exit 1))
(unless (and (not (poly<=? pn (expr->poly '(* p nobs))))
             (not (poly<=? (expr->poly '(* p nobs)) pn)))
  (printf "NG: unrelated extents must be incomparable\n") (exit 1))
(unless (poly<=? (expr->poly 'p) (expr->poly '(* p n)))
  (printf "NG: p <= pn under symbols >= 1\n") (exit 1))

;; counting: a fold inside a loop costs extent times length, and an
;; allocation costs its size
(define prog
  '((let ((t (make-vector (* p n) 0.0)))
      (range-for (j p)
        (vector-set! s j (array-sum (row x j)))))))
(define c (program-cost prog '((x (p n))) '()))
(unless (equal? (poly-eval c '((p . 10) (n . 100)))
                (+ (* 10 100)          ; the allocation
                   (* 10 (+ 1 100)))) ; p statements, each a length-n fold
  (printf "NG: cost count wrong: ~s\n"
          (poly-eval c '((p . 10) (n . 100))))
  (exit 1))

;; the covariance derivation, costed at benchmark sizes
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
(define dims '((x (p nobs))))
(define bx '((ps . n) (resid . nobs) (y . nobs)))
(define sizes '((p . 800) (nobs . 7200) (n . 8000) (wmax . 800)
                (iters . 200)))

(define-values (d log)
  (derive-fixpoint/log stmts 'resid 'beta #:restore? #f
                       #:extents '((ps . n) (y . nobs))))
(define c0 (poly-eval (program-cost stmts dims bx) sizes))
(define c1 (poly-eval (program-cost d dims bx) sizes))
(unless (and c0 c1 (< (* 5 c1) c0))
  (printf "NG: derived not at least 5x cheaper: ~s vs ~s\n" c0 c1)
  (exit 1))

;; The sizes-decided licence reaches the same fixpoint by a stricter
;; road.  Without sizes, the memo lowering is accepted early on the
;; weak credit that the residual copy dies; with sizes, the numeric
;; cost rightly rejects it until the Gram lowering has made the
;; design matrix the only thing keeping it expensive -- so the Gram
;; goes first, the inverse hoist follows, and the memo lowering lands
;; when it actually pays.  Same firings, better order, equal final
;; cost.
(let-values ([(d2 log2)
              (derive-fixpoint/log stmts 'resid 'beta #:restore? #f
                                   #:extents '((ps . n) (y . nobs))
                                   #:dims dims #:sizes sizes)])
  (unless (equal? log2
                  '(differencing merge lower precompute lower dead-fill))
    (printf "NG: sizes-decided firing order ~s\n" log2) (exit 1))
  (unless (equal? (sort (map symbol->string log2) string<?)
                  (sort (map symbol->string log) string<?))
    (printf "NG: firing multisets differ: ~s vs ~s\n" log2 log) (exit 1))
  (unless (equal? (poly-eval (program-cost d2 dims bx) sizes) c1)
    (printf "NG: final costs differ: ~s vs ~s\n"
            (poly-eval (program-cost d2 dims bx) sizes) c1)
    (exit 1)))

(printf "PASS cost-unit\n")

;; ---- the objective switch (SCM2CPP_COST=memory) ---------------------
;; Space is a polynomial of its own, and in memory mode it decides
;; before time does. The synthetic candidate trades an n-cell table
;; for a p*n loop: profitable to the clock, a pure loss to the cells.

(let ([sp (program-space
           '((let ((t (make-vector n 0.0)))
               (with-arrays ((t (n)))
                 (range-for (i n) (array-set! t i i))
                 0)))
           '() '())])
  (unless (poly-eval sp '((n . 7)))
    (printf "NG: program-space did not evaluate\n") (exit 1))
  (unless (= (poly-eval sp '((n . 7))) 14)   ; let + with-arrays, both counted
    (printf "NG: program-space miscounts: ~a\n" (poly-eval sp '((n . 7)))) (exit 1)))

(define spec-stmts
  '((range-for (j p)
      (range-for (i n)
        (array-set! out j (+ (array-ref out j) i))))))
(define spec-cand
  '((let ((t (make-vector n 0.0)))
      (with-arrays ((t (n)))
        (range-for (i n) (array-set! t i i))
        (range-for (j p) (array-set! out j (array-ref t 0)))
        0))))
(define spec-sizes '((n . 100) (p . 100)))
(putenv "SCM2CPP_COST" "")
(unless (speculation-ok? spec-stmts spec-cand '(out) '() '() spec-sizes)
  (printf "NG: speed mode should accept the table\n") (exit 1))
(putenv "SCM2CPP_COST" "memory")
(when (speculation-ok? spec-stmts spec-cand '(out) '() '() spec-sizes)
  (printf "NG: memory mode should refuse the table\n") (exit 1))

(printf "cost-objective checks pass\n")

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
(require (only-in (file "rewrite-search.scm") rewrite-search mem-cost)
         (only-in (file "scm-include.rkt") read-source-forms))

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

;; the rule search: tabulation of tree recursion flips with the mode
(define fib-prog
  '((define (fib n)
      (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
    (define (main) (begin (display (fib 20)) (newline) 0))))
(putenv "SCM2CPP_COST" "")
(define sped (rewrite-search fib-prog))
(putenv "SCM2CPP_COST" "memory")
(define memed (rewrite-search fib-prog))
(putenv "SCM2CPP_COST" "")
(unless (not (equal? sped fib-prog))
  (printf "NG: speed mode should tabulate fib\n") (exit 1))
(unless (equal? memed fib-prog)
  (printf "NG: memory mode should leave fib untabulated\n") (exit 1))
(unless (> (mem-cost sped) (mem-cost memed))
  (printf "NG: tabulated fib should cost more cells\n") (exit 1))

;; the covariance rewrite has a guarded doorway: the kernel that skips
;; the residual update of a coordinate that did not move (what
;; examples/kernel-only/lasso-kernel.scm is) still derives the Gram
;; form, and the guard is carried through to the c update; forcing the
;; family name reaches the doorway
(define (occurs? what e)
  (or (equal? what e)
      (and (pair? e) (or (occurs? what (car e)) (occurs? what (cdr e))))))
(define guarded-kernel (read-source-forms "examples/kernel-only/lasso-kernel.scm"))
(putenv "SCM2CPP_FORCE_RULE" "cd-covariance-update")
(define derived (rewrite-search guarded-kernel))
(putenv "SCM2CPP_FORCE_RULE" "")
(unless (occurs? '(make-vector (* p p) 0.0) derived)
  (printf "NG: the guarded kernel should derive the Gram form\n") (exit 1))
(unless (occurs? '(not (= bnew old)) derived)
  (printf "NG: the derived form should keep the guard\n") (exit 1))
(unless (occurs? '(vector-ref resid i) derived)   ; the one-time c build still reads it
  (printf "NG: the derived form lost the residual\n") (exit 1))
;; the kernel runs a path of penalties; the Gram matrix the rewrite
;; introduces inside that loop depends on X alone, and the hoist (which
;; the search finds by cost) moves its build in front of the loop
(define (find-form head e)
  (cond [(and (pair? e) (equal? (take* e 2) head)) e]
        [(pair? e) (or (find-form head (car e)) (find-form head (cdr e)))]
        [else #f]))
(define (take* e k) (if (or (zero? k) (not (pair? e))) '() (cons (car e) (take* (cdr e) (sub1 k)))))
(define path-loop (find-form '(do ((l 0 (+ l 1)))) derived))
(unless path-loop
  (printf "NG: the derived form lost the loop over penalties\n") (exit 1))
(when (occurs? '(make-vector (* p p) 0.0) path-loop)
  (printf "NG: the Gram build should be hoisted out of the loop over penalties\n") (exit 1))
(unless (occurs? '(make-vector p 0.0) path-loop)   ; c is per penalty
  (printf "NG: the c build belongs inside the loop over penalties\n") (exit 1))
;; the kernel stops after a sweep in which nothing moved, and the
;; derived form carries both flags: the one set inside the guard and
;; the one the sweep loop's exit reads
(unless (and (occurs? '(or (= sweep iters) (= stop 1)) derived)
             (occurs? '(set! moved 1) derived)
             (occurs? '(if (= moved 0) (set! stop 1) 0) derived))
  (printf "NG: the derived form lost the early stop\n") (exit 1))
(unless (let find ([e derived])
          (match e
            [`(if (not (= bnew old)) (begin (set! moved 1) (do ((,_ 0 (+ ,_ 1))) ,_ ...)) #f) #t]
            [(? pair?) (ormap find e)]
            [_ #f]))
  (printf "NG: the derived c update should sit under the guard with the moved flag\n") (exit 1))

;; the same kernel without its early stop -- a fixed number of sweeps,
;; the guard on the residual update kept -- derives through the guarded
;; doorway, and nothing of the stop appears in what it derives
(define (strip-early-stop e)
  (let strip ([e e])
    (match e
      [`(let ((stop 0))
          (do ((sweep 0 (+ sweep 1))) ((or (= sweep iters) (= stop 1)))
            (let ((moved 0)) ,jloop (if (= moved 0) (set! stop 1) 0))))
       `(do ((sweep 0 (+ sweep 1))) ((= sweep iters)) ,(strip jloop))]
      [`(if (not (= bnew old)) (begin (set! moved 1) ,loop) #f)
       `(if (not (= bnew old)) ,loop #f)]
      [(? pair?) (map strip e)]
      [_ e])))
(define fixed-kernel (strip-early-stop guarded-kernel))
(when (or (occurs? 'stop fixed-kernel) (occurs? 'moved fixed-kernel))
  (printf "NG: the test's fixed-sweep kernel still carries the early stop\n") (exit 1))
(putenv "SCM2CPP_FORCE_RULE" "cd-covariance-update")
(define fixed-derived (rewrite-search fixed-kernel))
(putenv "SCM2CPP_FORCE_RULE" "")
(unless (and (occurs? '(make-vector (* p p) 0.0) fixed-derived)
             (occurs? '(not (= bnew old)) fixed-derived)
             (not (occurs? 'stop fixed-derived)))
  (printf "NG: the fixed-sweep kernel should derive through the guarded doorway\n") (exit 1))
;; with nothing forced the cost order does not carry the covariance
;; rewrite, and nothing else touches the kernel: -R leaves it as written
(unless (equal? (rewrite-search guarded-kernel) guarded-kernel)
  (printf "NG: -R should leave the shipped kernel as written\n") (exit 1))
;; the elastic net in residual form derives through the same doorway:
;; the denominator of the step is a pattern variable, so the L2 share
;; of the penalty rides along, and the derived step is enet-descend's
(define enet-kernel (read-source-forms "examples/kernel-only/enet-kernel.scm"))
(putenv "SCM2CPP_FORCE_RULE" "cd-covariance-update")
(define enet-derived (rewrite-search enet-kernel))
(putenv "SCM2CPP_FORCE_RULE" "")
(unless (and (occurs? '(make-vector (* p p) 0.0) enet-derived)
             (occurs? '(+ (vector-ref xnorm j) (* lam2 (* 1.0 n))) enet-derived)
             (occurs? '(soft-threshold rho (* lam1 (* 1.0 n))) enet-derived)
             (occurs? '(if (= moved 0) (set! stop 1) 0) enet-derived))
  (printf "NG: the elastic net should derive the Gram form with its own step\n") (exit 1))
;; the denominator may not read the residual, which is stale during the
;; rewritten sweeps
(define enet-bad
  (let sub ([e enet-kernel])
    (match e
      [`(+ (vector-ref xnorm j) (* lam2 (* 1.0 n))) `(+ (vector-ref xnorm j) (vector-ref resid 0))]
      [(? pair?) (map sub e)]
      [_ e])))
(putenv "SCM2CPP_FORCE_RULE" "cd-covariance-update")
(unless (equal? (rewrite-search enet-bad) enet-bad)
  (printf "NG: a denominator reading the residual must not derive\n") (exit 1))
(putenv "SCM2CPP_FORCE_RULE" "")
(printf "cost-objective checks pass\n")

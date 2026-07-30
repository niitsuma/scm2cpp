#lang racket
;;;; A search-based source rewriter: the rule set as data, applied by
;;;; unification, chosen by cost.
;;;;
;;;; The hand-written recognisers in scm2cpp-match.scm are match clauses,
;;;; applied in a fixed order at fixed places. Here a rule is a value -- a
;;;; left pattern, a right template, a side condition -- and one generic
;;;; engine tries every rule at every subterm, using cKanren's unification
;;;; as the matcher. Unification gives nonlinear patterns for free: a
;;;; metavariable repeated in the pattern must match equal subterms, which
;;;; is exactly the index-discipline the loop shapes need. The engine
;;;; climbs while a rewrite lowers the static cost, so rule order stops
;;;; mattering, which is the point of moving from clauses to search.
;;;;
;;;; Rules are trusted only after passing their own embedded test: each
;;;; rule carries a small program pair, and at first use the engine runs
;;;; both sides and compares output. A rule whose test fails is dropped
;;;; with a message. Per-program verification stays where it was, in the
;;;; regression suite, since running the original of the very nest being
;;;; sped up can be too slow to do at translation time.

(require (only-in cKanren var == fresh run*))

(provide rewrite-search rewrite-search-enabled?)

(define (rewrite-search-enabled?) (and (getenv "SCM2CPP_REWRITE") #t))

;;;; ---------------- patterns ----------------
;;;; Metavariables are symbols beginning with ? . pattern->term replaces
;;;; them by logic variables, shared across the whole rule so the left
;;;; pattern binds and the right template reuses.

(define (pattern-var? x)
  (and (symbol? x) (char=? #\? (string-ref (symbol->string x) 0))))

(define (pattern->term pat env)   ; env : mutable hash ?sym -> logic var
  (cond [(pattern-var? pat) (hash-ref! env pat (lambda () (var pat)))]
        [(pair? pat) (cons (pattern->term (car pat) env)
                           (pattern->term (cdr pat) env))]
        [else pat]))

;; Match SUBTERM (ground) against LHS; on success return a lookup
;; procedure from metavariable name to matched value, else #f.
(define (match-pattern lhs subterm)
  (let* ([env (make-hash)]
         [lhs-term (pattern->term lhs env)]
         [names (hash-keys env)]
         [vars (map (lambda (n) (hash-ref env n)) names)]
         [sol (run* (q) (fresh () (== lhs-term subterm) (== q vars)))])
    (and (pair? sol)
         (let ([binding (map cons names (car sol))])
           (lambda (n) (cdr (assq n binding)))))))

(define (instantiate rhs lookup)
  (cond [(procedure? rhs) (rhs lookup)]   ; a build procedure, for rules
                                          ; whose output a template cannot say
        [(pattern-var? rhs) (lookup rhs)]
        [(pair? rhs) (cons (instantiate (car rhs) lookup)
                           (instantiate (cdr rhs) lookup))]
        [else rhs]))

;;;; ---------------- the rules ----------------
;;;; when : lookup -> boolean, checked after a structural match.
;;;; test : (original rewritten-expectation) as complete programs; the
;;;;        engine runs both and compares printed output.

(struct rule (name lhs rhs when test) #:transparent)

(define (distinct-symbols? . xs)
  (and (andmap symbol? xs)
       (= (length xs) (length (remove-duplicates xs)))))

(define rules
  (list
   ;; The scan lemma, rank 1: the sums over every prefix of V, produced by
   ;; re-summing each prefix from the start -- O(n^2) -- are one running
   ;; accumulation -- O(n). The source and destination must be different
   ;; arrays, or the running form reads cells it has just written.
   (rule
    'scan-lemma-1d
    '(do ((?I 0 (+ ?I 1))) ((= ?I ?N))
       (let ((?ACC ?Z))
         (do ((?A 0 (+ ?A 1))) ((= ?A (+ ?I 1)))
           (set! ?ACC (+ ?ACC (vector-ref ?V ?A))))
         (vector-set! ?S ?I ?ACC)))
    '(let ((?ACC ?Z))
       (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
         (set! ?ACC (+ ?ACC (vector-ref ?V ?I)))
         (vector-set! ?S ?I ?ACC)))
    (lambda (lk)
      (and (distinct-symbols? (lk '?V) (lk '?S) (lk '?ACC) (lk '?I) (lk '?A))
           (number? (lk '?Z)) (zero? (lk '?Z))))
    '((define (main)
        (let ((v (make-vector 7 0)) (s (make-vector 7 0)))
          (do ((k 0 (+ k 1))) ((= k 7)) (vector-set! v k (+ k 1)))
          (do ((i 0 (+ i 1))) ((= i 7))
            (let ((acc 0))
              (do ((a 0 (+ a 1))) ((= a (+ i 1)))
                (set! acc (+ acc (vector-ref v a))))
              (vector-set! s i acc)))
          (do ((k 0 (+ k 1))) ((= k 7))
            (display (vector-ref s k)) (display " "))
          (newline)))
      (main)))
   ;; The scan lemma, rank 2, as separability: the sum over every box
   ;; [0,i]x[0,j] -- O(n^4) when each box is re-summed -- is a prefix pass
   ;; along the rows followed by a prefix pass down the columns, in place
   ;; on the destination -- O(n^2). Each cell of S is read once and then
   ;; overwritten before the pass moves on, so the in-place column pass is
   ;; sound; V and S must again be different arrays.
   (rule
    'boxsum-2d-separable
    '(do ((?I 0 (+ ?I 1))) ((= ?I ?N))
       (do ((?J 0 (+ ?J 1))) ((= ?J ?N))
         (let ((?ACC ?Z))
           (do ((?A 0 (+ ?A 1))) ((= ?A (+ ?I 1)))
             (do ((?B 0 (+ ?B 1))) ((= ?B (+ ?J 1)))
               (set! ?ACC (+ ?ACC (vector-ref ?V (+ (* ?A ?N) ?B))))))
           (vector-set! ?S (+ (* ?I ?N) ?J) ?ACC))))
    '(begin
       (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
         (let ((?ACC ?Z))
           (do ((?J 0 (+ ?J 1))) ((= ?J ?N))
             (set! ?ACC (+ ?ACC (vector-ref ?V (+ (* ?I ?N) ?J))))
             (vector-set! ?S (+ (* ?I ?N) ?J) ?ACC))))
       (do ((?J 0 (+ ?J 1))) ((= ?J ?N))
         (let ((?ACC ?Z))
           (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
             (set! ?ACC (+ ?ACC (vector-ref ?S (+ (* ?I ?N) ?J))))
             (vector-set! ?S (+ (* ?I ?N) ?J) ?ACC)))))
    (lambda (lk)
      (and (distinct-symbols? (lk '?V) (lk '?S) (lk '?ACC)
                              (lk '?I) (lk '?J) (lk '?A) (lk '?B))
           (number? (lk '?Z)) (zero? (lk '?Z))))
    '((define (main)
        (let ((n 5) (v (make-vector 25 0)) (s (make-vector 25 0)))
          (do ((k 0 (+ k 1))) ((= k 25)) (vector-set! v k (+ 1 (remainder k 3))))
          (do ((i 0 (+ i 1))) ((= i n))
            (do ((j 0 (+ j 1))) ((= j n))
              (let ((acc 0))
                (do ((a 0 (+ a 1))) ((= a (+ i 1)))
                  (do ((b 0 (+ b 1))) ((= b (+ j 1)))
                    (set! acc (+ acc (vector-ref v (+ (* a n) b))))))
                (vector-set! s (+ (* i n) j) acc))))
          (do ((k 0 (+ k 1))) ((= k 25))
            (display (vector-ref s k)) (display " "))
          (newline)))
      (main)))
   ;; Tabulation: a pure unary function that recurses on (- n k) with
   ;; literal k, in tree form (two or more self-calls), is the classic
   ;; memoisation-plus-laziness case. Here the evaluation order that lazy
   ;; memo tables discover at run time is resolved statically: arguments
   ;; strictly decrease, so filling a table bottom-up visits every
   ;; dependency first, and each self-call becomes one table read. The
   ;; body must be a single pure expression; the right side is built by a
   ;; procedure, since a template cannot rewrite the body's self-calls.
   (rule
    'tabulate-recursion
    '(define (?F ?X) ?BODY)
    (lambda (lk)
      (let* ([f (lk '?F)] [n (lk '?X)] [body (lk '?BODY)]
             [whole (list 'define (list f n) body)]
             ;; The introduced names must not capture anything the function
             ;; already refers to -- a global spelt fib-tab, say.
             [tab (fresh-name (string->symbol (format "~a-tab" f)) whole)]
             [i (fresh-name (string->symbol (format "~a-i" f)) whole)])
        `(define (,f ,n)
           (let ((,tab (make-vector (+ ,n 1) 0)))
             (do ((,i 0 (+ ,i 1))) ((= ,i (+ ,n 1)))
               (vector-set! ,tab ,i ,(tabulate-body body f n tab i)))
             (vector-ref ,tab ,n)))))
    (lambda (lk)
      (let ([f (lk '?F)] [n (lk '?X)] [body (lk '?BODY)])
        (and (symbol? f) (symbol? n)
             (not (impure-body? body))
             (let ([args (self-call-args body f)])
               (and (>= (length args) 2)
                    (andmap (lambda (a)
                              (match a
                                [`(- ,m ,(? exact-positive-integer?)) (eq? m n)]
                                [_ #f]))
                            args))))))
    '((define (fib n)
        (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
      (define (main) (display (fib 15)) (newline))
      (main)))))

;;;; ---- helpers for the tabulation rule --------------------------------
;; The argument expressions of every unary self-call (F e) inside BODY.
(define (self-call-args body f)
  (cond [(and (pair? body) (eq? (car body) f) (= 2 (length body)))
         (cons (cadr body)
               (append-map (lambda (e) (self-call-args e f)) (cdr body)))]
        [(pair? body) (append-map (lambda (e) (self-call-args e f)) body)]
        [else '()]))
(define (impure-body? body)
  (cond [(and (pair? body)
              (memq (car body) '(set! vector-set! set-car! set-cdr! display newline)))
         #t]
        [(pair? body) (ormap impure-body? body)]
        [else #f]))
;; Does NAME occur anywhere in TERM? Used to keep introduced bindings from
;; capturing an existing variable of the same name.
(define (name-occurs? name term)
  (cond [(eq? name term) #t]
        [(pair? term) (or (name-occurs? name (car term))
                          (name-occurs? name (cdr term)))]
        [else #f]))
;; A name derived from BASE that does not occur in TERM: the base itself
;; when it is free, otherwise base-1, base-2, ... Deterministic, so the
;; generated program is stable across runs.
(define (fresh-name base term)
  (if (not (name-occurs? base term))
      base
      (let loop ([k 1])
        (let ([cand (string->symbol (format "~a-~a" base k))])
          (if (name-occurs? cand term) (loop (add1 k)) cand)))))
;; BODY with (F (- N k)) replaced by (vector-ref TAB (- I k)) and N by I.
(define (tabulate-body body f n tab i)
  (cond [(and (pair? body) (eq? (car body) f) (= 2 (length body)))
         (list 'vector-ref tab (tabulate-body (cadr body) f n tab i))]
        [(eq? body n) i]
        [(pair? body) (map (lambda (e) (tabulate-body e f n tab i)) body)]
        [else body]))

;;;; ---------------- rule self-test ----------------
;;;; Run the rule's test program as written and after one application of
;;;; the rule, in a fresh namespace, and compare what they print.

(define (run-program-for-output forms)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (parameterize ([current-namespace (make-base-namespace)])
      (with-output-to-string
        (lambda () (for ([f forms]) (eval f)))))))

(define (rewrite-once-with r expr)
  ;; first applicable position, preorder
  (let loop ([e expr])
    (let ([lk (match-pattern (rule-lhs r) e)])
      (cond
        [(and lk ((rule-when r) lk)) (instantiate (rule-rhs r) lk)]
        [(pair? e)
         (let sub ([xs e] [acc '()])
           (cond [(null? xs) #f]
                 [(pair? xs)
                  (let ([r2 (loop (car xs))])
                    (if r2
                        (append (reverse acc) (cons r2 (cdr xs)))
                        (sub (cdr xs) (cons (car xs) acc))))]
                 [else #f]))]
        [else #f]))))

(define (rule-passes-self-test? r)
  (let* ([orig (rule-test r)]
         [rewr (rewrite-once-with r orig)]
         [out1 (run-program-for-output orig)]
         [out2 (and rewr (run-program-for-output rewr))])
    (and out1 out2 (equal? out1 out2))))

(define checked-rules #f)
(define (usable-rules)
  (unless checked-rules
    (set! checked-rules
          (filter (lambda (r)
                    (or (rule-passes-self-test? r)
                        (begin (eprintf "rewrite-search: rule ~a failed its self-test; dropped~n"
                                        (rule-name r))
                               #f)))
                  rules)))
  checked-rules)

;;;; ---------------- cost and search ----------------
;;;; The static cost charges each do loop a factor over its body, so a
;;;; deeper nest costs more; the engine keeps rewriting while some single
;;;; rewrite lowers the cost. With cost-reducing rules this is plain hill
;;;; climbing, and rule order does not matter.

(define LOOP-FACTOR 8)
(define TREE-RECURSION-FACTOR 64)
(define (count-calls body f)
  (cond [(and (pair? body) (eq? (car body) f))
         (+ 1 (apply + (map (lambda (e) (count-calls e f)) (cdr body))))]
        [(pair? body) (apply + (map (lambda (e) (count-calls e f)) body))]
        [else 0]))
(define (cost e)
  (match e
    ;; Two or more self-calls is tree recursion, exponential unless
    ;; memoised; charge it so that tabulation registers as an improvement.
    [`(define (,(? symbol? f) ,_ ...) ,body ...)
     (* (if (>= (apply + (map (lambda (b) (count-calls b f)) body)) 2)
	    TREE-RECURSION-FACTOR 1)
	(max 1 (apply + (map cost body))))]
    [`(do ,_ ,_ ,body ...) (* LOOP-FACTOR (max 1 (apply + (map cost body))))]
    [(? pair?) (apply + (map cost e))]
    [_ 1]))

(define (all-one-step-rewrites expr)
  ;; every (rule, position) applied once, each giving a whole-program variant
  (append-map
   (lambda (r)
     (let ([out (rewrite-once-with r expr)])
       (if out (list (cons (rule-name r) out)) '())))
   (usable-rules)))

(define (rewrite-search expr)
  (let loop ([e expr] [applied '()] [fuel 10])
    (if (zero? fuel)
        e
        (let* ([cands (all-one-step-rewrites e)]
               [best (and (pair? cands)
                          (argmin (lambda (c) (cost (cdr c))) cands))])
          (if (and best (< (cost (cdr best)) (cost e)))
              (begin
                (eprintf "rewrite-search: applied ~a~n" (car best))
                (loop (cdr best) (cons (car best) applied) (sub1 fuel)))
              e)))))

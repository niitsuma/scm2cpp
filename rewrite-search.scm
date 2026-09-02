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

(require (only-in rkanren var == fresh run*))

(provide rewrite-search rewrite-search-enabled?
         parse-external-rule diagnose-rule rule-name mem-cost
         rule-sites rewrite-site)

(define (rewrite-search-enabled?)
  (and (or (getenv "SCM2CPP_REWRITE") (getenv "SCM2CPP_RULES")
           (getenv "SCM2CPP_FORCE_RULE"))
       #t))

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
    ;; ?WHOLE is reserved: it names the matched subterm itself, for
    ;; rules that wrap what they matched
    (and (pair? sol)
         (let ([binding (map cons names (car sol))])
           (lambda (n) (if (eq? n '?WHOLE) subterm (cdr (assq n binding))))))))

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

;; The covariance rewrite is one transformation with two doorways: the
;; imperative accumulator loop below, and the same loop as the fold macros
;; leave it -- a value-position named let, which the named-let pass
;; deliberately keeps (a do cannot return the accumulator).  The rule is
;; named here so that the fold-shaped variant can reuse its right-hand
;; side and its guard by reference instead of by copy.
;; The shared right-hand side.  With GUARD? the derived sweep skips the
;; c update of a coordinate that did not move, on the same condition the
;; source skips its residual update -- the guard is carried through, not
;; invented, and it is the economy the hand-written cov-descend has:
;; most coordinates of a sparse solution do not move, and each then
;; costs O(1) instead of O(p).
(define (cd-covariance-rhs lk guard?)
  (let* ([X (lk '?X)] [BETA (lk '?BETA)] [RESID (lk '?RESID)]
         [XNORM (lk '?XNORM)] [ST (lk '?ST)] [PEN (lk '?PEN)]
         [SW (lk '?SW)] [J (lk '?J)] [I (lk '?I)]
         [N (lk '?N)] [P (lk '?P)] [ITERS (lk '?ITERS)]
         [RHO (lk '?RHO)] [OLD (lk '?OLD)] [BNEW (lk '?BNEW)]
         [whole (list X BETA RESID XNORM ST PEN SW J I N P ITERS
                      RHO OLD BNEW)]
         [G (fresh-name 'gram whole)]
         [C (fresh-name 'xtr whole)]
         [B0 (fresh-name 'beta0 whole)]
         [K (fresh-name 'k whole)]
         [ACC (fresh-name 'acc whole)]
         [D (fresh-name 'd whole)]
         [update `(do ((,K 0 (+ ,K 1))) ((= ,K ,P))
                    (vector-set! ,C ,K
                                 (- (vector-ref ,C ,K)
                                    (* ,D (vector-ref ,G (+ (* ,J ,P) ,K))))))])
    `(let ((,G (make-vector (* ,P ,P) 0.0))
           (,C (make-vector ,P 0.0))
           (,B0 (make-vector ,P 0.0)))
       (do ((,J 0 (+ ,J 1))) ((= ,J ,P))
         (do ((,K 0 (+ ,K 1))) ((= ,K ,P))
           (let ((,ACC 0.0))
             (do ((,I 0 (+ ,I 1))) ((= ,I ,N))
               (set! ,ACC (+ ,ACC (* (vector-ref ,X (+ (* ,J ,N) ,I))
                                     (vector-ref ,X (+ (* ,K ,N) ,I))))))
             (vector-set! ,G (+ (* ,J ,P) ,K) ,ACC))))
       (do ((,J 0 (+ ,J 1))) ((= ,J ,P))
         (let ((,ACC 0.0))
           (do ((,I 0 (+ ,I 1))) ((= ,I ,N))
             (set! ,ACC (+ ,ACC (* (vector-ref ,X (+ (* ,J ,N) ,I))
                                   (vector-ref ,RESID ,I)))))
           (vector-set! ,C ,J ,ACC))
         (vector-set! ,B0 ,J (vector-ref ,BETA ,J)))
       (do ((,SW 0 (+ ,SW 1))) ((= ,SW ,ITERS))
         (do ((,J 0 (+ ,J 1))) ((= ,J ,P))
           (let ((,RHO (vector-ref ,C ,J))
                 (,OLD (vector-ref ,BETA ,J)))
             (set! ,RHO (+ ,RHO (* ,OLD (vector-ref ,XNORM ,J))))
             (let ((,BNEW (/ (,ST ,RHO ,PEN) (vector-ref ,XNORM ,J))))
               (vector-set! ,BETA ,J ,BNEW)
               (let ((,D (- ,BNEW ,OLD)))
                 ,(if guard?
                      `(if (not (= ,BNEW ,OLD)) ,update #f)
                      update))))))
       (do ((,J 0 (+ ,J 1))) ((= ,J ,P))
         (let ((,D (- (vector-ref ,BETA ,J) (vector-ref ,B0 ,J))))
           (do ((,I 0 (+ ,I 1))) ((= ,I ,N))
             (vector-set! ,RESID ,I
                          (- (vector-ref ,RESID ,I)
                             (* (vector-ref ,X (+ (* ,J ,N) ,I)) ,D)))))))))

(define cd-covariance-rule
  (rule
    'cd-covariance-update
    '(do ((?SW 0 (+ ?SW 1))) ((= ?SW ?ITERS))
       (do ((?J 0 (+ ?J 1))) ((= ?J ?P))
         (let ((?RHO 0.0)
               (?OLD (vector-ref ?BETA ?J)))
           (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
             (set! ?RHO (+ ?RHO (* (vector-ref ?X (+ (* ?J ?N) ?I))
                                   (vector-ref ?RESID ?I)))))
           (set! ?RHO (+ ?RHO (* ?OLD (vector-ref ?XNORM ?J))))
           (let ((?BNEW (/ (?ST ?RHO ?PEN) (vector-ref ?XNORM ?J))))
             (vector-set! ?BETA ?J ?BNEW)
             (do ((?I2 0 (+ ?I2 1))) ((= ?I2 ?N))
               (vector-set! ?RESID ?I2
                            (- (vector-ref ?RESID ?I2)
                               (* (vector-ref ?X (+ (* ?J ?N) ?I2))
                                  (- ?BNEW ?OLD)))))))))
    (lambda (lk) (cd-covariance-rhs lk #f))
    (lambda (lk)
      (and (distinct-symbols? (lk '?X) (lk '?BETA) (lk '?RESID) (lk '?XNORM)
                              (lk '?SW) (lk '?J) (lk '?I)
                              (lk '?RHO) (lk '?OLD) (lk '?BNEW))
           (symbol? (lk '?ST))
           ;; The bounds are re-evaluated freely on the right side, and
           ;; more often than on the left; only names and literals are
           ;; safe to duplicate.
           (andmap (lambda (v) (or (symbol? v) (number? v)))
                   (list (lk '?N) (lk '?P) (lk '?ITERS)))
           ;; The penalty may read anything the two sides keep equal --
           ;; beta, the bounds, enclosing lets -- but not the residual,
           ;; which is stale during the rewritten sweeps.
           (not (name-occurs? (lk '?RESID) (lk '?PEN)))))
    ;; Dyadic data end to end: integer entries, column norms a power of
    ;; two, penalty 1.0. Every intermediate is then exact in a double, so
    ;; the two forms print identical digits; with general data they agree
    ;; only to rounding, which a string comparison cannot grade.
    '((define (soft-threshold z g)
        (cond ((> z g) (- z g))
              ((< z (- 0.0 g)) (+ z g))
              (else 0.0)))
      (define (main)
        (let ((n 4) (p 3) (iters 3)
              (x (vector 1.0 1.0 1.0 1.0
                         1.0 -1.0 1.0 -1.0
                         2.0 0.0 0.0 0.0))
              (beta (vector 0.0 0.0 0.0))
              (resid (vector 3.0 1.0 2.0 0.0))
              (xnorm (vector 4.0 4.0 4.0))
              (lam 0.25))
          (do ((sweep 0 (+ sweep 1))) ((= sweep iters))
            (do ((j 0 (+ j 1))) ((= j p))
              (let ((rho 0.0)
                    (old (vector-ref beta j)))
                (do ((i 0 (+ i 1))) ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                      (vector-ref resid i)))))
                (set! rho (+ rho (* old (vector-ref xnorm j))))
                (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                               (vector-ref xnorm j))))
                  (vector-set! beta j bnew)
                  (do ((i 0 (+ i 1))) ((= i n))
                    (vector-set! resid i
                                 (- (vector-ref resid i)
                                    (* (vector-ref x (+ (* j n) i))
                                       (- bnew old)))))))))
          (do ((j 0 (+ j 1))) ((= j p))
            (display (vector-ref beta j)) (display " "))
          (do ((i 0 (+ i 1))) ((= i n))
            (display (vector-ref resid i)) (display " "))
          (newline)))
      (main))))

;; The guarded doorway: the same descent when it skips the residual
;; update of a coordinate that did not move -- what lasso-kernel.scm is,
;; and what scikit-learn's descent does.  The guard is a statement-
;; position if whose else branch is #f, the subset's convention for a
;; loop's non-recursive tail; the builder carries it through to the c
;; update.  The pattern is structural like every rule's: the guard must
;; be written exactly (not (= bnew old)), the form the kernel uses.
(define cd-covariance-guarded-rule
  (rule
    'cd-covariance-update-guarded
    '(do ((?SW 0 (+ ?SW 1))) ((= ?SW ?ITERS))
       (do ((?J 0 (+ ?J 1))) ((= ?J ?P))
         (let ((?RHO 0.0)
               (?OLD (vector-ref ?BETA ?J)))
           (do ((?I 0 (+ ?I 1))) ((= ?I ?N))
             (set! ?RHO (+ ?RHO (* (vector-ref ?X (+ (* ?J ?N) ?I))
                                   (vector-ref ?RESID ?I)))))
           (set! ?RHO (+ ?RHO (* ?OLD (vector-ref ?XNORM ?J))))
           (let ((?BNEW (/ (?ST ?RHO ?PEN) (vector-ref ?XNORM ?J))))
             (vector-set! ?BETA ?J ?BNEW)
             (if (not (= ?BNEW ?OLD))
                 (do ((?I2 0 (+ ?I2 1))) ((= ?I2 ?N))
                   (vector-set! ?RESID ?I2
                                (- (vector-ref ?RESID ?I2)
                                   (* (vector-ref ?X (+ (* ?J ?N) ?I2))
                                      (- ?BNEW ?OLD)))))
                 #f)))))
    (lambda (lk) (cd-covariance-rhs lk #t))
    (rule-when cd-covariance-rule)
    '((define (soft-threshold z g)
        (cond ((> z g) (- z g))
              ((< z (- 0.0 g)) (+ z g))
              (else 0.0)))
      (define (main)
        (let ((n 4) (p 3) (iters 3)
              (x (vector 1.0 1.0 1.0 1.0
                         1.0 -1.0 1.0 -1.0
                         2.0 0.0 0.0 0.0))
              (beta (vector 0.0 0.0 0.0))
              (resid (vector 3.0 1.0 2.0 0.0))
              (xnorm (vector 4.0 4.0 4.0))
              (lam 0.25))
          (do ((sweep 0 (+ sweep 1))) ((= sweep iters))
            (do ((j 0 (+ j 1))) ((= j p))
              (let ((rho 0.0)
                    (old (vector-ref beta j)))
                (do ((i 0 (+ i 1))) ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* j n) i))
                                      (vector-ref resid i)))))
                (set! rho (+ rho (* old (vector-ref xnorm j))))
                (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                               (vector-ref xnorm j))))
                  (vector-set! beta j bnew)
                  (if (not (= bnew old))
                      (do ((i 0 (+ i 1))) ((= i n))
                        (vector-set! resid i
                                     (- (vector-ref resid i)
                                        (* (vector-ref x (+ (* j n) i))
                                           (- bnew old)))))
                      #f)))))
          (do ((j 0 (+ j 1))) ((= j p))
            (display (vector-ref beta j)) (display " "))
          (do ((i 0 (+ i 1))) ((= i n))
            (display (vector-ref resid i)) (display " "))
          (newline)))
      (main))))

;; Skipping a null update.  A loop that adds E*D to every cell of an
;; array, D fixed for the whole loop, does nothing when D is zero, so it
;; may be guarded by that test: the guard is one comparison and the loop
;; it saves is O(n).  The rewrite is an identity by construction (the
;; body with D = 0 substituted writes each cell back to itself, exactly,
;; up to the sign of a zero and provided E is finite), so correctness is
;; not the question; whether the guard ever fires is.  That D is often
;; exactly zero is a fact about the algorithm -- a coordinate descent
;; with a soft threshold leaves most coordinates where they were, a
;; gradient step never lands on zero -- which the source does not state,
;; so like the covariance rewrite this one never fires from the cost
;; search (it adds a node); it is applied by name, or at the sites a
;; model nominates (skip-propose.rkt).  D written as a difference is
;; guarded as the equality of its two sides, which is the form the
;; guarded doorway of cd-covariance-update recognises.
;;
;; The when clause sees the parent of the match (rewrite-parent), so
;; that a loop already sitting under its guard is not guarded again.
(define rewrite-parent (make-parameter #f))
(define (null-update-guard d)
  (match d
    [`(- ,a ,b) `(= ,a ,b)]
    [_ `(= ,d 0)]))
(define (already-guarded? loop)
  (match (rewrite-parent)
    [`(if (not ,_) ,body #f) (eq? body loop)]
    [_ #f]))
(define (skip-null-update-rhs lk)
  (let ([loop (lk '?WHOLE)])
    `(if (not ,(null-update-guard (lk '?D))) ,loop #f)))
(define (skip-null-update-when lk)
  (let ([i (lk '?I)] [a (lk '?A)] [d (lk '?D)] [loop (lk '?WHOLE)])
    (and (symbol? i) (symbol? a) (memq (lk '?OP) '(+ -))
         ;; D must be the same on every iteration and not depend on the
         ;; array being updated
         (not (name-occurs? i d)) (not (name-occurs? a d))
         ;; the parts skipped must not have been doing anything else
         (not (impure-body? (list (lk '?N) (lk '?IDX) (lk '?E) d)))
         (not (already-guarded? loop)))))
(define skip-null-update-test
  '((define (main)
      (let ((n 4) (a (vector 1.0 2.0 3.0 4.0)) (x (vector 1.0 -1.0 2.0 0.5))
            (steps (vector 0.5 0.25 -1.0)) (old 0.25))
        (do ((k 0 (+ k 1))) ((= k 3))
          (let ((bnew (vector-ref steps k)))
            (do ((i 0 (+ i 1))) ((= i n))
              (vector-set! a i (- (vector-ref a i)
                                  (* (vector-ref x i) (- bnew old)))))))
        (do ((i 0 (+ i 1))) ((= i n)) (display (vector-ref a i)) (display " "))
        (newline)))
    (main)))
;; ?WHOLE is bound to the whole match by the engine (see match-pattern),
;; so the right side can wrap the loop as it stood.
(define skip-null-update-rule
  (rule
    'skip-null-update
    '(do ((?I 0 (+ ?I 1))) ((= ?I ?N))
       (vector-set! ?A ?IDX (?OP (vector-ref ?A ?IDX) (* ?E ?D))))
    skip-null-update-rhs
    skip-null-update-when
    skip-null-update-test))
;; the doorway with the fixed factor on the left
(define skip-null-update-left-rule
  (rule
    'skip-null-update-left
    '(do ((?I 0 (+ ?I 1))) ((= ?I ?N))
       (vector-set! ?A ?IDX (?OP (vector-ref ?A ?IDX) (* ?D ?E))))
    skip-null-update-rhs
    skip-null-update-when
    '((define (main)
        (let ((n 4) (a (vector 1.0 2.0 3.0 4.0)) (x (vector 1.0 -1.0 2.0 0.5))
              (steps (vector 0.5 0.0 -1.0)))
          (do ((k 0 (+ k 1))) ((= k 3))
            (let ((d (vector-ref steps k)))
              (do ((i 0 (+ i 1))) ((= i n))
                (vector-set! a i (+ (vector-ref a i) (* d (vector-ref x i)))))))
          (do ((i 0 (+ i 1))) ((= i n)) (display (vector-ref a i)) (display " "))
          (newline)))
      (main))))
;; Hoisting an invariant table.  A loop whose body allocates a table and
;; fills it from values the loop never changes builds the same table on
;; every iteration; the allocation and the fill move out in front of
;; the loop, and the body keeps the reads.  This is what the covariance
;; rewrite leaves behind when the descent it rewrote sits inside a loop
;; over penalties: the Gram matrix depends on X alone, and only its use
;; -- c, the sweeps, the restore -- belongs to each penalty.  The check
;; is the ordinary one for loop-invariant code: the fill writes nothing
;; but the table, reads nothing the loop binds or writes, and the table
;; is written nowhere else and named nowhere outside its let.  The
;; static cost sees the fill leave the loop, so this rule fires from the
;; search on its own.
(define (symbols-in e)
  (cond [(symbol? e) (list e)]
        [(pair? e) (append (symbols-in (car e)) (symbols-in (cdr e)))]
        [else '()]))
(define (written-in e)
  (match e
    [`(set! ,(? symbol? v) ,rhs) (cons v (written-in rhs))]
    [`(vector-set! ,(? symbol? v) ,idx ,rhs) (cons v (append (written-in idx) (written-in rhs)))]
    [(? pair?) (append-map written-in e)]
    [_ '()]))
(define (bound-in e)
  (match e
    [`(do ,binds ,_ ,body ...)
     (append (map car binds) (append-map bound-in (map cdr binds)) (append-map bound-in body))]
    [`(let ,(? symbol? nm) ,binds ,body ...)
     (cons nm (append (map car binds) (append-map bound-in (map cdr binds)) (append-map bound-in body)))]
    [`(let ,binds ,body ...)
     (append (map car binds) (append-map bound-in (map cdr binds)) (append-map bound-in body))]
    [`(lambda ,args ,body ...) (append (symbols-in args) (append-map bound-in body))]
    [(? pair?) (append-map bound-in e)]
    [_ '()]))
(define (effectful? e)
  (cond [(and (pair? e) (memq (car e) '(display newline set-car! set-cdr!))) #t]
        [(pair? e) (ormap effectful? e)]
        [else #f]))
;; Statement positions of BODY (a list of statements), with a way to put
;; a replacement in: returns (list stmt replace) for each, preorder.
(define (statement-sites stmts)
  (let walk ([stmts stmts] [put (lambda (new) new)])
    (append*
     (for/list ([st stmts] [k (in-naturals)])
       (let ([put-here (lambda (new) (put (list-set stmts k new)))])
         (cons (list st put-here)
               (match st
                 [`(let ,(? list? binds) ,body ...)
                  (walk body (lambda (nb) (put-here `(let ,binds ,@nb))))]
                 [`(begin ,body ...)
                  (walk body (lambda (nb) (put-here `(begin ,@nb))))]
                 [`(do ,binds ,stop ,body ...)
                  (walk body (lambda (nb) (put-here `(do ,binds ,stop ,@nb))))]
                 [_ '()])))))))
;; The first hoistable (let ...) in BODY, the body of a loop over L:
;; (list V SZ INIT FILL new-body) or #f.
(define (find-hoist l body)
  (for/or ([site (statement-sites body)])
    (match (first site)
      [`(let ,(? list? binds) ,fill ,rest ...)
       (for/or ([b binds])
         (match b
           [`(,(? symbol? v) (make-vector ,sz ,(? number? init)))
            (let* ([others (remove b binds)]
                   [replaced ((second site) (if (null? others) `(begin ,@rest) `(let ,others ,@rest)))]
                   ;; the body with the let cut out: V may be read in
                   ;; the let's own body, nowhere else
                   [outside (symbols-in ((second site) 'hoisted-let))]
                   [bound (bound-in replaced)]
                   [written (written-in replaced)]
                   [fill-free (remove* (cons v (bound-in fill)) (symbols-in fill))]
                   [fill-writes (remove* (bound-in fill) (written-in fill))])
              (and (not (memq v outside))
                   (not (memq v written))
                   (not (memq l (symbols-in sz)))
                   (null? (filter (lambda (x) (or (memq x bound) (memq x written))) (symbols-in sz)))
                   (andmap (lambda (w) (eq? w v)) fill-writes)
                   (pair? fill-writes)
                   (not (effectful? fill))
                   (not (memq l fill-free))
                   (null? (filter (lambda (x) (or (memq x bound) (memq x written))) fill-free))
                   (list v sz init fill replaced)))]
           [_ #f]))]
      [_ #f])))
(define hoist-invariant-table-rule
  (rule
    'hoist-invariant-table
    '(do ((?L 0 (+ ?L 1))) ((= ?L ?NL)) . ?BODY)
    (lambda (lk)
      (match (find-hoist (lk '?L) (lk '?BODY))
        [(list v sz init fill body)
         `(let ((,v (make-vector ,sz ,init)))
            ,fill
            (do ((,(lk '?L) 0 (+ ,(lk '?L) 1))) ((= ,(lk '?L) ,(lk '?NL)))
              ,@body))]))
    (lambda (lk)
      (and (symbol? (lk '?L)) (list? (lk '?BODY))
           (not (memq (lk '?L) (symbols-in (lk '?NL))))
           (find-hoist (lk '?L) (lk '?BODY))
           #t))
    '((define (main)
        (let ((n 3) (x (vector 1.0 2.0 4.0)) (out (vector 0.0 0.0)))
          (do ((l 0 (+ l 1))) ((= l 2))
            (let ((t (make-vector 3 0.0)) (s 0.0))
              (do ((i 0 (+ i 1))) ((= i n))
                (vector-set! t i (* (vector-ref x i) (vector-ref x i))))
              (do ((i 0 (+ i 1))) ((= i n))
                (set! s (+ s (* (vector-ref t i) (+ l 1.0)))))
              (vector-set! out l s)))
          (display (vector-ref out 0)) (display " ")
          (display (vector-ref out 1)) (newline)))
      (main))))

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
      (main)))
   ;; Covariance updates for coordinate descent (the glmnet arrangement).
   ;; The left side is descent with an explicit residual: each coordinate
   ;; recomputes rho = x_j . resid in O(n) and then walks the residual
   ;; again to apply the step, so a sweep costs O(n p). The right side
   ;; forms the Gram matrix once, keeps c = X' resid up to date through
   ;; c[k] -= d * G[j][k], and touches no observation inside the sweeps:
   ;; O(n p^2) once, then O(p) per coordinate. The residual is a visible
   ;; output of the left side, so it is brought current at the end in one
   ;; O(n p) pass from the total movement of beta.
   ;;
   ;; Three choices keep the rule honest. XNORM is used exactly where the
   ;; original used it and is never assumed to hold the column norms; the
   ;; Gram matrix alone maintains c, so c[k] = x_k . resid holds exactly
   ;; whatever the caller passed. The shrink operator is a pattern
   ;; variable, not a fixed name, because both sides call it with equal
   ;; arguments in the same order; it must not read RESID behind its
   ;; arguments' back, which cannot be seen from here and stands as the
   ;; rule's one contract. And the penalty expression is opaque but must
   ;; not mention RESID, the only state the two sides let disagree
   ;; mid-sweep.
   cd-covariance-rule
   cd-covariance-guarded-rule
   skip-null-update-rule
   skip-null-update-left-rule
   hoist-invariant-table-rule

   ;; The fold-shaped doorway.  What the engine sees after macro expansion
   ;; of (range-fold ((r 0.0) (i n)) (+ r (* x[jn+i] resid[i]))) is a
   ;; value-position named let; ?LOOP matches its gensym'd name.  Bindings
   ;; are arranged so the shared builder finds every hole it uses under
   ;; the same names as in the imperative doorway.
   (rule
    'cd-covariance-update-fold
    '(do ((?SW 0 (+ ?SW 1))) ((= ?SW ?ITERS))
       (do ((?J 0 (+ ?J 1))) ((= ?J ?P))
         (let ((?OLD (vector-ref ?BETA ?J)))
           (let ((?RHO (+ (let ?LOOP ((?I 0) (?R 0.0))
                            (if (= ?I ?N)
                                ?R
                                (?LOOP (+ ?I 1)
                                       (+ ?R (* (vector-ref ?X (+ (* ?J ?N) ?I))
                                                (vector-ref ?RESID ?I))))))
                          (* ?OLD (vector-ref ?XNORM ?J)))))
             (let ((?BNEW (/ (?ST ?RHO ?PEN) (vector-ref ?XNORM ?J))))
               (vector-set! ?BETA ?J ?BNEW)
               (do ((?I2 0 (+ ?I2 1))) ((= ?I2 ?N))
                 (vector-set! ?RESID ?I2
                              (- (vector-ref ?RESID ?I2)
                                 (* (vector-ref ?X (+ (* ?J ?N) ?I2))
                                    (- ?BNEW ?OLD))))))))))
    (lambda (lk) ((rule-rhs cd-covariance-rule) lk))
    (lambda (lk)
      (and ((rule-when cd-covariance-rule) lk)
           (symbol? (lk '?LOOP)) (symbol? (lk '?R))
           (distinct-symbols? (lk '?LOOP) (lk '?R) (lk '?I)
                              (lk '?RHO) (lk '?OLD) (lk '?J))
           ;; the loop name must be the fold's own: nothing else may call it
           (not (name-occurs? (lk '?LOOP) (lk '?PEN)))))
    '((define (soft-threshold z g)
        (cond ((> z g) (- z g))
              ((< z (- 0.0 g)) (+ z g))
              (else 0.0)))
      (define (main)
        (let ((n 4) (p 3) (iters 3)
              (x (vector 1.0 1.0 1.0 1.0
                         1.0 -1.0 1.0 -1.0
                         2.0 0.0 0.0 0.0))
              (beta (vector 0.0 0.0 0.0))
              (resid (vector 3.0 1.0 2.0 0.0))
              (xnorm (vector 4.0 4.0 4.0))
              (lam 0.25))
          (do ((sweep 0 (+ sweep 1))) ((= sweep iters))
            (do ((j 0 (+ j 1))) ((= j p))
              (let ((old (vector-ref beta j)))
                (let ((rho (+ (let accloop ((i 0) (r 0.0))
                                (if (= i n)
                                    r
                                    (accloop (+ i 1)
                                             (+ r (* (vector-ref x (+ (* j n) i))
                                                     (vector-ref resid i))))))
                              (* old (vector-ref xnorm j)))))
                  (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                                 (vector-ref xnorm j))))
                    (vector-set! beta j bnew)
                    (do ((i 0 (+ i 1))) ((= i n))
                      (vector-set! resid i
                                   (- (vector-ref resid i)
                                      (* (vector-ref x (+ (* j n) i))
                                         (- bnew old))))))))))
          (do ((j 0 (+ j 1))) ((= j p))
            (display (vector-ref beta j)) (display " "))
          (do ((i 0 (+ i 1))) ((= i n))
            (display (vector-ref resid i)) (display " "))
          (newline)))
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
  (let loop ([e expr] [parent #f])
    (let ([lk (match-pattern (rule-lhs r) e)])
      (cond
        [(and lk (parameterize ([rewrite-parent parent]) ((rule-when r) lk)))
         (instantiate (rule-rhs r) lk)]
        [(pair? e)
         (let sub ([xs e] [acc '()])
           (cond [(null? xs) #f]
                 [(pair? xs)
                  (let ([r2 (loop (car xs) e)])
                    (if r2
                        (append (reverse acc) (cons r2 (cdr xs)))
                        (sub (cdr xs) (cons (car xs) acc))))]
                 [else #f]))]
        [else #f]))))

(define (rule-passes-self-test? r)
  ;; Any error while matching or instantiating -- a template metavariable
  ;; the pattern never binds, say -- counts as failing the test.
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let* ([orig (rule-test r)]
           [rewr (rewrite-once-with r orig)]
           [out1 (run-program-for-output orig)]
           [out2 (and rewr (run-program-for-output rewr))])
      (and out1 out2 (equal? out1 out2)))))

;;;; ---------------- external rules ----------------
;;;; SCM2CPP_RULES names a file of additional rules -- written by hand or
;;;; proposed by a language model. They pass through the same self-test as
;;;; the built-in ones, which is the point: a proposed rule whose two sides
;;;; disagree on its own test is dropped before it can touch any program.
;;;; External rules are deliberately less expressive than built-in ones:
;;;; the right side is a template, not a procedure, and the side condition
;;;; is drawn from a fixed vocabulary rather than being arbitrary code, so
;;;; reading a rules file never executes anything the file says.
;;;;
;;;;   (rule NAME
;;;;     (lhs PATTERN)          ; metavariables are ?x
;;;;     (rhs TEMPLATE)
;;;;     (when COND ...)        ; optional: (distinct ?a ?b ...) (symbol ?x)
;;;;                            ;           (number ?x) (zero ?x)
;;;;     (test FORM ...))       ; a complete program that prints; mandatory

(define (conds->proc conds)
  (lambda (lk)
    (andmap
     (lambda (c)
       (match c
         [`(distinct ,vs ...) (apply distinct-symbols? (map lk vs))]
         [`(symbol ,v) (symbol? (lk v))]
         [`(number ,v) (number? (lk v))]
         [`(zero ,v) (let ([x (lk v)]) (and (number? x) (zero? x)))]
         [_ #f]))
     conds)))

(define (parse-external-rule form)
  (match form
    [`(rule ,(? symbol? name) (lhs ,l) (rhs ,r) (when ,cs ...) (test ,t ...))
     (rule name l r (conds->proc cs) t)]
    [`(rule ,(? symbol? name) (lhs ,l) (rhs ,r) (test ,t ...))
     (rule name l r (lambda (_) #t) t)]
    [_ #f]))

(define (load-external-rules)
  (let ([path (getenv "SCM2CPP_RULES")])
    (if (not path)
        '()
        (with-handlers ([(lambda (_) #t)
                         (lambda (_)
                           (eprintf "rewrite-search: cannot read rules file ~a~n" path)
                           '())])
          (filter-map
           (lambda (f)
             (or (parse-external-rule f)
                 (begin (eprintf "rewrite-search: malformed rule skipped: ~a~n"
                                 (if (and (pair? f) (pair? (cdr f))) (cadr f) f))
                        #f)))
           (with-input-from-file path
             (lambda ()
               (let loop ([acc '()])
                 (let ([f (read)])
                   (if (eof-object? f) (reverse acc) (loop (cons f acc)))))))))))) 

;; Why a rule fails, in a form a reviser -- human or model -- can act on:
;;   ok                        the rule passes its own test
;;   (malformed)               not a well-formed rule s-expression
;;   (no-match)                the left side matches nothing in the test
;;   (test-does-not-run)       the test program itself does not run
;;   (rewritten-crashes)       the rewritten test raises an error
;;   (outputs-differ O R)      both run; original prints O, rewritten R
(define (diagnose-rule r)
  (with-handlers ([(lambda (_) #t) (lambda (_) '(rewritten-crashes))])
    (let* ([orig (rule-test r)]
           [rewr (rewrite-once-with r orig)])
      (cond
        [(not rewr) '(no-match)]
        [else
         (let ([out1 (run-program-for-output orig)])
           (cond
             [(not out1) '(test-does-not-run)]
             [else
              (let ([out2 (run-program-for-output rewr)])
                (cond
                  [(not out2) '(rewritten-crashes)]
                  [(equal? out1 out2) 'ok]
                  [else (list 'outputs-differ out1 out2)]))]))]))))

(define checked-rules #f)
(define (usable-rules)
  (unless checked-rules
    (set! checked-rules
          (filter (lambda (r)
                    (or (rule-passes-self-test? r)
                        (begin (eprintf "rewrite-search: rule ~a failed its self-test; dropped~n"
                                        (rule-name r))
                               #f)))
                  (append rules (load-external-rules)))))
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

;; The memory objective, in the same crude spirit as the loop factor:
;; an allocation is charged MEM-FACTOR per symbolic factor of its size,
;; so a table of n cells costs 8 and an n*m table 64, comparable
;; against the zero of a program that allocates nothing. It exists for
;; SCM2CPP_COST=memory, where it decides first and the time cost above
;; only breaks ties -- a tabulation that trades a table for the
;; tree-recursion factor is then a loss, not a win.
(define MEM-FACTOR 8)
(define (size-degree e)
  (match e
    [(? number?) 0]
    [(? symbol?) 1]
    [`(* ,a ...) (apply + (map size-degree a))]
    [`(,(or '+ '-) ,a ...) (apply max 0 (map size-degree a))]
    [_ 1]))
(define (mem-cost e)
  (match e
    [`(make-vector ,n ,_ ...)
     (+ (expt MEM-FACTOR (max 1 (size-degree n))) (mem-cost n))]
    [`(with-arrays ,decls ,body ...)
     (+ (for/sum ([d decls]) (expt MEM-FACTOR (max 1 (length (cadr d)))))
        (for/sum ([b body]) (mem-cost b)))]
    [(? pair?) (for/sum ([x e]) (mem-cost x))]
    [_ 0]))

(define (memory-objective?)
  (equal? (getenv "SCM2CPP_COST") "memory"))
;; the pair (memory, time) under the mode's order: speed mode pins the
;; first component to zero, so the comparison collapses to the old one
(define (objective e)
  (cons (if (memory-objective?) (mem-cost e) 0) (cost e)))
(define (obj<? a b)
  (or (< (car a) (car b))
      (and (= (car a) (car b)) (< (cdr a) (cdr b)))))

(define (all-one-step-rewrites expr)
  ;; every (rule, position) applied once, each giving a whole-program variant
  (append-map
   (lambda (r)
     (let ([out (rewrite-once-with r expr)])
       (if out (list (cons (rule-name r) out)) '())))
   (usable-rules)))

;; A rule named in SCM2CPP_FORCE_RULE is applied wherever it matches,
;; profitable by the static model or not. The model charges every loop the
;; same factor, so a rewrite that pays once to make every later sweep
;; cheap -- covariance updates being the standing example -- looks like a
;; loss to it; whether the one-time cost amortises depends on run counts
;; the source does not contain. Naming the rule is the user asserting that
;; it does, in the same spirit as -I: the structural match and the rule's
;; self-test still gate, only the profitability judgement moves to the
;; caller.
(define (force-rule-names)
  (let ([s (getenv "SCM2CPP_FORCE_RULE")])
    (if (or (not s) (string=? s ""))
        '()
        (map string->symbol (string-split s ",")))))

;; A rule's doorways are named NAME-*: forcing NAME forces the family,
;; so the caller asserts the rewrite, not the shape the source happens
;; to be written in.
(define (rule-family nm)
  (let ([prefix (string-append (symbol->string nm) "-")])
    (filter (lambda (q)
              (let ([qn (symbol->string (rule-name q))])
                (or (eq? (rule-name q) nm)
                    (and (> (string-length qn) (string-length prefix))
                         (string=? prefix (substring qn 0 (string-length prefix)))))))
            (usable-rules))))

;; Several names, comma-separated, are applied in the order given: the
;; skip guard first and the covariance rewrite after it is the pipeline
;; that takes the plain kernel to the guarded Gram form.
(define (apply-forced-rule expr)
  (for/fold ([e expr]) ([nm (force-rule-names)])
    (let ([rs (rule-family nm)])
      (if (null? rs)
          (begin (eprintf "rewrite-search: forced rule ~a unknown or failing its self-test~n" nm)
                 e)
          (let loop ([e e] [fuel 10])
            (let ([hit (and (positive? fuel)
                            (for/or ([r rs])
                              (let ([out (rewrite-once-with r e)])
                                (and out (cons (rule-name r) out)))))])
              (if hit
                  (begin (eprintf "rewrite-search: applied ~a (forced)~n" (car hit))
                         (loop (cdr hit) (sub1 fuel)))
                  e)))))))

;;;; ---------------- sites, for the proposers ----------------
;;;; Where a rule family matches in a program, numbered in preorder, and
;;;; the program with the rule applied at one such site only.  This is
;;;; what lets a caller -- skip-propose.rkt, a model behind it -- choose
;;;; the sites rather than take every match, which is what forcing does.

(define (rule-sites nm expr)
  (let ([rs (rule-family nm)] [acc '()] [k 0])
    (let walk ([e expr] [parent #f])
      (let ([hit (for/or ([r rs])
                   (let ([lk (match-pattern (rule-lhs r) e)])
                     (and lk (parameterize ([rewrite-parent parent]) ((rule-when r) lk))
                          (cons r lk))))])
        ;; each site: its number, the doorway that took it, the subterm,
        ;; and the match's lookup so a caller can name the parts
        (when hit
          (set! acc (cons (list k (rule-name (car hit)) e (cdr hit)) acc))
          (set! k (add1 k)))
        ;; a matched site is not descended into: forcing rewrites it
        ;; whole and its inside is then a different program
        (when (and (not hit) (pair? e))
          (for ([x e]) (walk x e)))))
    (reverse acc)))

(define (rewrite-site nm expr site)
  (let ([rs (rule-family nm)] [k 0])
    (let walk ([e expr] [parent #f])
      (let* ([hit (for/or ([r rs])
                    (let ([lk (match-pattern (rule-lhs r) e)])
                      (and lk (parameterize ([rewrite-parent parent]) ((rule-when r) lk))
                           (cons r lk))))])
        (cond [hit
               (let ([mine (= k site)])
                 (set! k (add1 k))
                 (if mine (instantiate (rule-rhs (car hit)) (cdr hit)) e))]
              [(pair? e) (map (lambda (x) (walk x e)) e)]
              [else e])))))

(define (rewrite-search expr)
  (let loop ([e (apply-forced-rule expr)] [applied '()] [fuel 10])
    (if (zero? fuel)
        e
        (let* ([cands (all-one-step-rewrites e)]
               [best (and (pair? cands)
                          (for/fold ([b (car cands)]) ([c (cdr cands)])
                            (if (obj<? (objective (cdr c)) (objective (cdr b)))
                                c b)))])
          (if (and best (obj<? (objective (cdr best)) (objective e)))
              (begin
                (eprintf "rewrite-search: applied ~a~n" (car best))
                (loop (cdr best) (cons (car best) applied) (sub1 fuel)))
              e)))))

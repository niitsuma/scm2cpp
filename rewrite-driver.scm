#lang racket
;;;; The fixpoint driver of the design note: alternate the improvement
;;;; rules over a statement list until none fires.  Nothing here is
;;;; specific to the lasso; the driver tries each rule anywhere it can
;;;; and keeps whatever strictly went through.
;;;;
;;;;   differencing   the sweep that admits incrementalize is replaced
;;;;                  by its derived block (fires once: the derived
;;;;                  block offers no further scratch update);
;;;;   subset merge   a fill whose table is an index-restricted
;;;;                  instance of another's is dropped, its reads
;;;;                  redirected -- the column norms fold into the
;;;;                  Gram diagonal here;
;;;;   normalization  a fill element that inlines to slice views,
;;;;   + lowering     distributes, and lowers to a lag-indexed prefix
;;;;                  table is rewritten in place, the table built in
;;;;                  a local scope just before it.
;;;;
;;;; Each firing deletes a table, removes a scratch traversal, or
;;;; replaces folds by table reads, so the loop descends a cost order
;;;; and the fuel bound is never the thing that stops it.  Rules
;;;; refuse rather than half-fire: a failed lowering leaves its fill
;;;; exactly as written.

(require (only-in (file "rewrite-incremental.scm")
                  incrementalize subst walk-collect)
         (only-in (file "rewrite-precompute.scm")
                  precompute-const table-subset-plan apply-table-merge
                  dead-fill-plan)
         (only-in (file "rewrite-normalize.scm")
                  collect-fill-defs inline-normalize normalize-fold)
         (only-in (file "rewrite-lagsum.scm") lag-lower)
         (only-in (file "rewrite-contract.scm") contract-axis)
         (only-in (file "rewrite-cost.scm")
                  program-cost program-space poly<? poly-eval)
         (only-in (file "rewrite-raise.scm") raise-loops))

(provide derive-fixpoint derive-fixpoint/log
         try-differencing try-merge try-precompute try-lower try-dead-fill
         speculation-ok?)

(define (walk-sites e)
  (let loop ([e e] [acc '()])
    (let ([acc (if (pair? e) (cons e acc) acc)])
      (if (pair? e)
          (loop (cdr e) (loop (car e) acc))
          acc))))

;; ---- differencing: the first statement incrementalize accepts ----

;; restore? may be #t, #f, or 'auto.  Auto decides from the statement
;; list alone: restoration is owed exactly when some later statement
;; still reads the scratch vector.  For a kernel that declares its
;; scratch locally and never looks at it after the sweep -- the
;; recommended shape -- this is a syntactic fact, and no
;; interprocedural liveness is involved.  The parameter-liveness pass
;; remains the licence for kernels that do expose the scratch in
;; their signature.
;; Only sweep-shaped statements are offered: a range-for or a do loop at
;; the head.  A let or a begin in statement position is entered and its
;; statements offered in turn, so a kernel whose sweep sits under a
;; (let ((stop 0)) ..) derives too, with the tables built in front of
;; the sweep loop, not in front of the let.  The derived block is a
;; let, and must be -- with restoration on it contains a memo context
;; and an update of the scratch vector, which is exactly the shape
;; differencing looks for, and re-differencing its own emission
;; regresses forever.  The head test is this rule's instance of sealing
;; rule output against re-application: the let itself is never offered,
;; and its statements each lack one half of the shape (the fills read
;; the scratch but do not update it, the restoration updates it but
;; does not read it, the sweep no longer mentions it).
(define (try-differencing stmts v beta restore?)
  ;; AFTER: the statements that follow the current list in the
  ;; enclosing ones, for the 'auto decision.
  (let walk ([stmts stmts] [after '()])
    (let loop ([pre '()] [rest stmts])
      (cond [(null? rest) #f]
            [(not (pair? (car rest)))
             (loop (cons (car rest) pre) (cdr rest))]
            [(memq (caar rest) '(range-for do))
             (define r
               (if (eq? restore? 'auto)
                   (for/or ([s (append (cdr rest) after)])
                     (and (memq v (walk-collect symbol? s)) #t))
                   restore?))
             (cond
               [(incrementalize (car rest) v beta #:restore? r)
                => (lambda (d) (append (reverse pre) (list d) (cdr rest)))]
               [else (loop (cons (car rest) pre) (cdr rest))])]
            [(match (car rest)
               [`(let ,(? list? bs) ,body ...)
                (let ([new (walk body (append (cdr rest) after))])
                  (and new `(let ,bs ,@new)))]
               [`(begin ,body ...)
                (let ([new (walk body (append (cdr rest) after))])
                  (and new `(begin ,@new)))]
               [_ #f])
             => (lambda (d) (append (reverse pre) (list d) (cdr rest)))]
            [else (loop (cons (car rest) pre) (cdr rest))]))))

;; ---- subset merge, with the merged fills dropped ----

;; The comparison runs modulo normalization: each definition is
;; inlined and distributed before the subset search, so two fills that
;; write the same table through different doorways -- array-dot
;; against array-sum of a product, or a read of a defined array
;; against its unfolded form -- still recognize each other.  Only the
;; comparison sees the normalized text; the program keeps its own,
;; which is why this costs nothing and cannot oscillate.  Extra driver
;; rounds could never recover these merges: the rules are functions of
;; the program text, so a zero-firing round is already the fixpoint.
(define (defs3 stmts)
  (define raw (collect-fill-defs stmts))
  (for/list ([d raw])
    (match-define (list name idx exts expr) d)
    (define others (filter (lambda (o) (not (eq? (car o) name))) raw))
    (list name idx
          (or (inline-normalize expr others) (normalize-fold expr)))))

(define (fill-of? s names)
  (let loop ([s s] [depth 0])
    (match s
      [`(range-for (,_ ,_) ,inner) (loop inner (add1 depth))]
      [`(,(or 'vector-set! 'array-set!) ,(? symbol? a) ,_ ...)
       (and (> depth 0) (memq a names) #t)]
      [_ #f])))

(define (drop-fills e names)
  (let go ([e e])
    (cond [(fill-of? e names) 0]
          [(list? e) (map go e)]
          [else e])))

(define (try-merge stmts)
  (let* ([d3 (defs3 stmts)]
         [plan (table-subset-plan d3)])
    (and (pair? plan)
         (drop-fills (apply-table-merge stmts plan d3)
                     (map car plan)))))

;; ---- const folds hoisted out of their loops ----

;; precompute-const carries its own cost gate -- only a fold
;; re-evaluated across iterations its table would absorb fires -- so
;; the driver may offer it every statement every round without
;; re-hoisting the builds it already emitted.
(define (try-precompute stmts)
  (let loop ([pre '()] [rest stmts])
    (cond [(null? rest) #f]
          [(precompute-const (car rest))
           => (lambda (h) (append (reverse pre) (list h) (cdr rest)))]
          [else (loop (cons (car rest) pre) (cdr rest))])))

;; ---- normalization + lag lowering on a fill element ----

;; Both fill shapes lower the same way; they differ in the licence.
;; A rank-two fill replaces extent-many folds per table row, so a
;; successful lowering is kept outright.  A rank-one fill is not
;; locally profitable -- the table costs about what the folds did --
;; and is kept speculatively: only when the rewrite leaves some fill
;; with no reader, so the dead-fill rule collects it next round, does
;; the candidate stand; otherwise it rolls back.  This is the
;; enabling-credit acceptance of the design note in its smallest form.
(define (lower-replacement low fill)
  (let ([decls (car low)])
    `(let (,@(for/list ([d decls])
               `(,(car d) (make-vector (* ,@(cadr d)) 0.0))))
       (with-arrays ,decls
         ,(cadr low)
         ,fill
         0))))

;; The speculative licence, in three layers.  With concrete sizes the
;; unified cost polynomial decides outright: both programs are
;; cleaned of dead fills and the candidate must cost strictly less.
;; Without sizes the symbolic comparison decides where it can --
;; every extent at least one -- and where it is silent, the old
;; enabling test stands: the candidate must leave some fill NEWLY
;; unread, one that was not already dead before it.
;; SCM2CPP_COST=memory flips the objective order: allocated cells
;; decide, and the time comparison below becomes the tiebreak. The
;; default is the time-first behaviour, unchanged.
(define (memory-objective?)
  (equal? (getenv "SCM2CPP_COST") "memory"))

(define (speculation-ok? stmts cand live-out dims base-exts sizes)
  (define (cleanup s)
    (let loop ([s s])
      (cond [(try-dead-fill s live-out) => loop] [else s])))
  (define cls (cleanup stmts))
  (define clc (cleanup cand))
  (define cs (program-cost cls dims base-exts))
  (define cc (program-cost clc dims base-exts))
  (define (time-decides)
    (cond
      [(and sizes (poly-eval cc sizes) (poly-eval cs sizes))
       (< (poly-eval cc sizes) (poly-eval cs sizes))]
      [(poly<? cc cs) #t]
      [(poly<? cs cc) #f]
      [else (pair? (remove* (dead-fill-plan stmts live-out)
                            (dead-fill-plan cand live-out)))]))
  (if (not (memory-objective?))
      (time-decides)
      (let ([ss (program-space cls dims base-exts)]
            [sc (program-space clc dims base-exts)])
        (cond
          [(and sizes (poly-eval sc sizes) (poly-eval ss sizes))
           (cond [(< (poly-eval sc sizes) (poly-eval ss sizes)) #t]
                 [(> (poly-eval sc sizes) (poly-eval ss sizes)) #f]
                 [else (time-decides)])]
          [(poly<? sc ss) #t]
          [(poly<? ss sc) #f]
          [else (time-decides)]))))

(define (try-lower stmts base-exts live-out dims sizes)
  (define ds (collect-fill-defs stmts))
  (define (attempt site elem coord-exts rebuild speculative?)
    (let* ([a-name (car rebuild)]
           [others (filter (lambda (d) (not (eq? (car d) a-name))) ds)]
           [norm (inline-normalize elem others)])
      (and norm (not (equal? norm elem))
           (let ([low (lag-lower norm base-exts coord-exts)])
             (and low
                  (let* ([fill ((cdr rebuild) (caddr low))]
                         [cand (subst site (lower-replacement low fill)
                                      stmts)])
                    (if speculative?
                        (and (speculation-ok? stmts cand live-out
                                              dims base-exts sizes)
                             cand)
                        cand)))))))
  (for/or ([site (walk-sites stmts)])
    (match site
      [`(range-for (,(? symbol? w) ,P)
          (range-for (,(? symbol? i) ,N)
            (array-set! ,(? symbol? a) ,w2 ,i2 ,elem)))
       #:when (and (eq? w w2) (eq? i i2))
       (attempt site elem (list (cons w P) (cons i N))
                (cons a (lambda (e)
                          `(range-for (,w ,P)
                             (range-for (,i ,N)
                               (array-set! ,a ,w ,i ,e)))))
                #f)]
      [`(range-for (,(? symbol? k) ,P)
          (,(and setter (or 'array-set! 'vector-set!))
           ,(? symbol? a) ,k2 ,elem))
       #:when (eq? k k2)
       (attempt site elem (list (cons k P))
                (cons a (lambda (e)
                          `(range-for (,k ,P) (,setter ,a ,k ,e))))
                #t)]
      [_ #f])))

;; ---- fills nothing reads ----

(define (try-dead-fill stmts live-out)
  (let ([plan (dead-fill-plan stmts live-out)])
    (and (pair? plan) (drop-fills stmts plan))))

;; ---- the loop ----

;; Every round offers every rule; the loop ends only when a full
;; round fires nothing, which is the fixpoint itself -- a first round
;; with no firing means the program already was one.  The log names
;; each firing in order, so a caller can see which rules carried a
;; derivation and which had nothing to do.
(define (derive-fixpoint/log stmts v beta
                             #:restore? [restore? #t]
                             #:extents [base-exts '()]
                             #:live-out [live-out #f]
                             #:dims [dims '()]
                             #:sizes [sizes #f])
  (define outs (or live-out (list beta)))
  (let loop ([stmts stmts] [fired '()] [fuel 20])
    (define (fire tag s) (loop s (cons tag fired) (sub1 fuel)))
    (cond [(zero? fuel) (values stmts (reverse fired))]
          [(raise-loops stmts dims base-exts)
           => (lambda (s) (fire 'raise s))]
          [(try-differencing stmts v beta restore?)
           => (lambda (s) (fire 'differencing s))]
          [(try-merge stmts) => (lambda (s) (fire 'merge s))]
          [(try-precompute stmts) => (lambda (s) (fire 'precompute s))]
          [(try-lower stmts base-exts outs dims sizes)
           => (lambda (s) (fire 'lower s))]
          [(contract-axis stmts dims) => (lambda (s) (fire 'contract s))]
          [(try-dead-fill stmts outs) => (lambda (s) (fire 'dead-fill s))]
          [else (values stmts (reverse fired))])))

(define (derive-fixpoint stmts v beta
                         #:restore? [restore? #t]
                         #:extents [base-exts '()]
                         #:live-out [live-out #f]
                         #:dims [dims '()]
                         #:sizes [sizes #f])
  (let-values ([(s _) (derive-fixpoint/log stmts v beta
                                           #:restore? restore?
                                           #:extents base-exts
                                           #:live-out live-out
                                           #:dims dims
                                           #:sizes sizes)])
    s))

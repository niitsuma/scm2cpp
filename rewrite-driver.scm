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

(require (only-in (file "rewrite-incremental.scm") incrementalize subst)
         (only-in (file "rewrite-precompute.scm")
                  precompute-const table-subset-plan apply-table-merge)
         (only-in (file "rewrite-normalize.scm")
                  collect-fill-defs inline-normalize normalize-fold)
         (only-in (file "rewrite-lagsum.scm") lag-lower))

(provide derive-fixpoint derive-fixpoint/log)

(define (walk-sites e)
  (let loop ([e e] [acc '()])
    (let ([acc (if (pair? e) (cons e acc) acc)])
      (if (pair? e)
          (loop (cdr e) (loop (car e) acc))
          acc))))

;; ---- differencing: the first statement incrementalize accepts ----

(define (try-differencing stmts v beta restore?)
  (let loop ([pre '()] [rest stmts])
    (cond [(null? rest) #f]
          [(incrementalize (car rest) v beta #:restore? restore?)
           => (lambda (d) (append (reverse pre) (list d) (cdr rest)))]
          [else (loop (cons (car rest) pre) (cdr rest))])))

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

(define (drop-fills e names)
  (let go ([e e])
    (match e
      [`(range-for (,_ ,_)
          (,(or 'vector-set! 'array-set!) ,(? symbol? a) ,_ ...))
       #:when (memq a names)
       0]
      [`(range-for (,_ ,_)
          (range-for (,_ ,_) (array-set! ,(? symbol? a) ,_ ...)))
       #:when (memq a names)
       0]
      [(? list?) (map go e)]
      [_ e])))

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

(define (try-lower stmts base-exts)
  (define ds (collect-fill-defs stmts))
  (for/or ([site (walk-sites stmts)])
    (match site
      [`(range-for (,(? symbol? w) ,P)
          (range-for (,(? symbol? i) ,N)
            (array-set! ,(? symbol? a) ,w2 ,i2 ,elem)))
       #:when (and (eq? w w2) (eq? i i2))
       (let* ([others (filter (lambda (d) (not (eq? (car d) a))) ds)]
              [norm (inline-normalize elem others)])
         (and norm (not (equal? norm elem))
              (let ([low (lag-lower norm base-exts
                                    (list (cons w P) (cons i N)))])
                (and low
                     (let* ([cs (car low)]
                            [dims (cadr (car low))]
                            [replacement
                             `(let ((,(car cs) (make-vector (* ,@dims) 0.0)))
                                (with-arrays ((,(car cs) ,dims))
                                  ,(cadr low)
                                  (range-for (,w ,P)
                                    (range-for (,i ,N)
                                      (array-set! ,a ,w ,i ,(caddr low))))
                                  0))])
                       (subst site replacement stmts))))))]
      [_ #f])))

;; ---- the loop ----

;; Every round offers every rule; the loop ends only when a full
;; round fires nothing, which is the fixpoint itself -- a first round
;; with no firing means the program already was one.  The log names
;; each firing in order, so a caller can see which rules carried a
;; derivation and which had nothing to do.
(define (derive-fixpoint/log stmts v beta
                             #:restore? [restore? #t]
                             #:extents [base-exts '()])
  (let loop ([stmts stmts] [fired '()] [fuel 20])
    (define (fire tag s) (loop s (cons tag fired) (sub1 fuel)))
    (cond [(zero? fuel) (values stmts (reverse fired))]
          [(try-differencing stmts v beta restore?)
           => (lambda (s) (fire 'differencing s))]
          [(try-merge stmts) => (lambda (s) (fire 'merge s))]
          [(try-precompute stmts) => (lambda (s) (fire 'precompute s))]
          [(try-lower stmts base-exts) => (lambda (s) (fire 'lower s))]
          [else (values stmts (reverse fired))])))

(define (derive-fixpoint stmts v beta
                         #:restore? [restore? #t]
                         #:extents [base-exts '()])
  (let-values ([(s _) (derive-fixpoint/log stmts v beta
                                           #:restore? restore?
                                           #:extents base-exts)])
    s))

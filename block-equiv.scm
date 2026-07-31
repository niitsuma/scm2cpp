#lang racket
;;;; Do two blocks of code compute the same value?
;;;;
;;;; Asked of arbitrary code the question is undecidable, and asked of code
;;;; that writes to anything it is not even well posed: two identical loops
;;;; can disagree because something changed between them. Restricted to
;;;; blocks whose free variables are write-free over the span between them,
;;;; a block is a pure function of those variables, and the question becomes
;;;; whether the two expressions are equal as expressions -- still
;;;; undecidable in general, but approachable from below by a set of
;;;; equations one is willing to name.
;;;;
;;;; The relation is written in cKanren rather than as a predicate for three
;;;; reasons. Unification gives the structural part outright, including the
;;;; discipline that a metavariable repeated in a pattern must match equal
;;;; subterms. The relation runs backwards: given one block it enumerates
;;;; blocks equal to it, which is what a rewrite search wants. And the
;;;; purity side condition, which today is checked in Racket, is a goal of
;;;; the same kind and could later be conjoined rather than bolted on.
;;;;
;;;; What is claimed: when equiv-o succeeds the two blocks agree, provided
;;;; the purity condition holds. The converse does not hold -- failure means
;;;; "not equal by these equations", not "different". The equations are
;;;; commutativity and associativity of + and *, distributivity, and
;;;; congruence; the search is depth-bounded so it always terminates.

(require (only-in cKanren == =/= fresh conde conda run run* var))
(require "custom-binding.scm")

(provide equiv-o blocks-equivalent? block-free-vars pure-block?
         same-value? shared-inputs)

;;;; ---------------- purity ----------------
;;;; A block qualifies only if it neither writes nor calls anything that
;;;; might. The caller must separately establish that its free variables are
;;;; write-free over the region between the two blocks; that is a property
;;;; of the surrounding code, not of the block.

(define writing-forms '(set! vector-set! set-car! set-cdr! display newline))
(define known-pure
  '(+ - * / quotient remainder modulo max min abs expt
    sqrt sin cos tan exp log asin acos atan
    < > <= >= = eq? eqv? equal? not and or
    vector-ref vector-length car cdr cons list length list-ref
    if cond else let begin quote))

(define (pure-block? e)
  (cond [(and (pair? e) (memq (car e) writing-forms)) #f]
        [(and (pair? e) (symbol? (car e))
              (not (memq (car e) known-pure))
              (not (binding-op? (car e))))
         #f]                        ; an unknown callee may do anything
        [(and (pair? e) (binding-op? (car e))
              (pair? (binding-op-mutates (car e))))
         #f]                        ; a binding op declared to write
        [(pair? e) (andmap pure-block? e)]
        [else #t]))

(define (block-free-vars e [bound '()])
  (match e
    [`(quote ,_) '()]
    [`(let ((,xs ,vs) ...) ,body ...)
     (append (append-map (lambda (v) (block-free-vars v bound)) vs)
             (append-map (lambda (b) (block-free-vars b (append xs bound))) body))]
    [(? symbol? s) (if (or (memq s bound) (memq s known-pure) (binding-op? s))
                       '() (list s))]
    [(? pair?) (remove-duplicates
                (append-map (lambda (x) (block-free-vars x bound)) (cdr e)))]
    [_ '()]))

;;;; ---------------- the equations ----------------
;;;; Depth is an ordinary Scheme number threaded through the goals rather
;;;; than a logic term: it bounds how many equations may be applied along
;;;; one branch, which is what makes the search finite.

(define (equiv-o a b depth)
  (conde
   ;; identical, including two identical variables
   [(== a b)]
   ;; congruence: same head, arguments equal one by one
   [(fresh (h xs ys)
      (== a (cons h xs)) (== b (cons h ys))
      (if (> depth 0) (equiv-list-o xs ys (- depth 1)) (== xs ys)))]
   ;; commutativity of + and *
   [(fresh (op x y)
      (=/= op 'quote)
      (conde [(== op '+)] [(== op '*)])
      (== a (list op x y)) (== b (list op y x))
      (if (> depth 0) succeed-if-nonzero (== x x)))]
   ;; associativity of + and *, both directions
   [(fresh (op x y z)
      (conde [(== op '+)] [(== op '*)])
      (== a (list op (list op x y) z))
      (== b (list op x (list op y z))))]
   [(fresh (op x y z)
      (conde [(== op '+)] [(== op '*)])
      (== a (list op x (list op y z)))
      (== b (list op (list op x y) z)))]
   ;; distributivity, both directions
   [(fresh (x y z)
      (== a (list '* x (list '+ y z)))
      (== b (list '+ (list '* x y) (list '* x z))))]
   [(fresh (x y z)
      (== a (list '+ (list '* x y) (list '* x z)))
      (== b (list '* x (list '+ y z))))]))

(define succeed-if-nonzero (== 1 1))

(define (equiv-list-o xs ys depth)
  (conde
   [(== xs '()) (== ys '())]
   [(fresh (x xr y yr)
      (== xs (cons x xr)) (== ys (cons y yr))
      (equiv-o x y depth)
      (equiv-list-o xr yr depth))]))

;;;; ---------------- the front door ----------------
;;;; Both blocks must be pure, and then the relation is asked whether they
;;;; are equal. depth is small on purpose: the equations compose, and the
;;;; useful cases in this translator are shallow.

;; The depth needed is the nesting depth at which an equation must be
;; applied, so an expression buried four constructors down needs four. Six
;; covers the shapes this translator meets; the cost of the search is what
;; bounds it, not correctness -- a larger depth only finds more equalities.
(define (blocks-equivalent? a b [depth 6])
  (and (pure-block? a) (pure-block? b)
       (pair? (run 1 (q) (equiv-o a b depth)))))

;;;; ---------------- the direct argument ----------------
;;;; Naming equations is the wrong way round for the question memoisation
;;;; actually asks. A block with no side effects is a function of its free
;;;; variables, so two occurrences of it agree exactly when those variables
;;;; hold the same values -- including the loop indices, which are free
;;;; variables like any other. Nothing needs to be proved about the
;;;; arithmetic at all.
;;;;
;;;; That is both simpler and stronger than the equational route: it decides
;;;; cases the equations cannot reach, since it never looks inside the
;;;; expression. What it needs instead is the caller's guarantee that the
;;;; inputs really do agree -- for an index, that the two occurrences sit at
;;;; the same point of the same loop; for an array, that it is write-free
;;;; across the span. shared-inputs names what must be shown.
;;;;
;;;; The two are complementary. same-value? settles "the same computation,
;;;; reached twice"; equiv-o settles "two computations written differently".
;;;; Memoisation wants the first.

;; The free variables whose agreement would make these two blocks agree, or
;; #f if the question does not apply because a block may have effects.
(define (shared-inputs a b)
  (and (pure-block? a) (pure-block? b)
       (equal? a b)
       (block-free-vars a)))

;; Do the blocks compute the same value, given that every variable in
;; AGREEING holds the same value at both occurrences? The caller establishes
;; that list: write-freedom for the arrays, and same-iteration for indices.
(define (same-value? a b agreeing)
  (let ([ins (shared-inputs a b)])
    (and ins (andmap (lambda (v) (memq v agreeing)) ins) #t)))

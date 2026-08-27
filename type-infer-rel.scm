;;;; A note on the numeric tower, which took a wrong turn first.
;;;;
;;;; int and double were separate types here, and arithmetic chose between
;;;; them. Read that way a whole program often has no typing at all --
;;;; bench/sqrttest.scm has none -- and it looked like the relation was
;;;; failing to find the general answer. It was not. Asked what
;;;; (lambda (x) (* x x)) can be, it answers
;;;;
;;;;   (-> (int) int)
;;;;   (-> (double) double)
;;;;
;;;; and that is the whole answer: two instantiations of one polymorphic
;;;; function. The right type is the one C++ writes as a template and
;;;; instantiates once the call site says which number it has, which is what
;;;; type-infer-hm.scm's unifier already does -- it rebinds a numeric type
;;;; variable when it meets a wider one, "which is what lets x in (* x x)
;;;; become double once a later call site says so", and leaves a template
;;;; parameter where nothing ever says. Enumerating the instances is not the
;;;; same thing as having the type, and a program of any size has too many
;;;; combinations to enumerate.
;;;;
;;;; So this pass settles shapes and leaves width alone: square is
;;;; (-> (num) num), average (-> (num num) num), and which of them becomes a
;;;; template and which becomes double is decided afterwards, by the pass
;;;; that already decides it, reading the same 2.0 in the same source. That
;;;; is numeric-mode's 'unified, and it is the default.
;;;;
;;;; 'split keeps the enumerating reading, which is worth having for one
;;;; question: a term with more than one typing under it is polymorphic, so
;;;; asking for several answers is how you find out that square is a
;;;; template and that average returns double however it is called.
;;;;
#lang racket
;;;; A relational Hindley-Milner inferencer for the subset scm2cpp translates.
;;;;
;;;; The pass in type-infer-hm.scm is algorithm W: it runs one way, from a
;;;; program to its types, and that is all a translator strictly needs. This
;;;; one is a relation. It runs that way too, and it also runs backwards --
;;;; given a type, it enumerates terms of that type -- which is what makes it
;;;; useful to the proposer tools: a rewrite a language model offers can be
;;;; checked against the type its context demands, and a hole can be filled by
;;;; asking for inhabitants rather than by asking a model to guess.
;;;;
;;;; It is built on the relational inferencer of William Byrd, by way of
;;;; Hirotaka Niitsuma's Racket port, over the miniKanren in
;;;; vendor/mk-recursive whose occurs check names a self-referential binding
;;;; instead of refusing it. That last part is why a stream has a type here:
;;;; the type of (cons a (delay b)) contains itself, algorithm W needs the
;;;; nominal (scm2cpp-stream T) to say so, and this pass derives it as
;;;; (==> T (pair A (promise T))) without being told.
;;;;
;;;; Types:
;;;;
;;;;   int double bool void string    base
;;;;   (-> (T ...) R)                 function
;;;;   (vec N T)                      vector of T, N its extent: a number
;;;;                                  when a literal construction fixes it,
;;;;                                  and otherwise left open, which is the
;;;;                                  std::vector case. An open extent
;;;;                                  unifies with a known one and the known
;;;;                                  one wins, so a parameter first seen
;;;;                                  through indexing takes the caller's
;;;;                                  length -- the rule type-infer-hm.scm
;;;;                                  spells 'unsized.
;;;;   (pair A B)                     cons cell
;;;;   (promise T)                    what delay makes and force takes
;;;;   (==> x T)                      T, with x inside it standing for T
;;;;
;;;; The environment is an association list of (x : T) and, for a let-bound
;;;; name, (x poly e gamma): its type is re-derived at each use, which is how
;;;; let-polymorphism is had relationally -- the derivation supplies fresh
;;;; variables every time.
;;;;
;;;; What it costs.
;;;;
;;;; It types the whole of examples/kernel-only/lasso-cov.scm -- all six
;;;; definitions, together -- in about seventy seconds, and gets the shapes
;;;; right: build-S takes four vectors and three numbers, cov-descend three
;;;; and four. Getting there took one change and five false starts.
;;;;
;;;; The five that did nothing, each worth half or nothing: binding let
;;;; monomorphically first, collapsing the numeric tower, committing to one
;;;; typing per definition, keeping the special-form test out of the
;;;; constraint store, and dropping the polymorphic reading of let. Tabling,
;;;; the textbook remedy for a search that re-derives its own subterms, is
;;;; not available: the implementation that exists handles == and no other
;;;; constraint, where this relation leans on symbolo and =/=, and it forbids
;;;; free logic variables inside a tabled goal, while the type argument of
;;;; (!-o gamma e T) is free by construction.
;;;;
;;;; The one that worked was not in this file. A profile put ninety-eight per
;;;; cent of the time in assq, inside walk, looking down an association list
;;;; of some thousands of bindings; the substitution in vendor/mk-recursive
;;;; now carries a hash of itself for walk to read, and the same inference is
;;;; twenty-nine times faster. It was never a search problem. It was a lookup
;;;; that was linear in the size of the substitution, in the innermost loop
;;;; of the whole system.
;;;;
;;;; One correctness note, which matters more than the speed. In 'split mode
;;;; the numeric tower is a choice, so the relation returns a typing rather
;;;; than the principal one: soft-threshold comes back as (-> (int double)
;;;; double), which is consistent but too narrow for its callers, and
;;;; committing to it makes them fail. Arithmetic has to unify rather than
;;;; branch for the answer to be principal, which is what 'unified does,
;;;; leaving the int-against-double decision where the emitter already makes
;;;; it.

(provide numeric-mode let-mode type->nominal !-o programo programo/complete infer-type infer-type* infer-program inhabitants
         numo widen-o base-type?)

(require "vendor/mk-recursive/mk.scm")

;; ---------------------------------------------------------------- numbers

(define (base-type? t) (memq t '(int double bool void string)))

;; How the numeric tower is modelled during inference.
;;
;;   'unified  one numeric type: arithmetic unifies rather than choosing,
;;             and width is left to the pass that already settles it, which
;;             is also the pass that decides what stays a template. This is
;;             the reading a program wants and the default.
;;   'split    int and double as alternatives, enumerated. A term with more
;;             than one typing under this reading is polymorphic, which is
;;             how to ask whether a function is a template; a program of any
;;             size has no single consistent assignment and gets no typing.
(define numeric-mode (make-parameter 'unified))

(define (numo t)
  (case (numeric-mode)
    [(unified) (== t 'num)]
    [else (conde ((== t 'int)) ((== t 'double)))]))

;; What arithmetic does to a pair of numeric types, which is what C++ would
;; do to them: the wider of the two wins, and int with int stays int.
;; A result the tower fixes -- division and sqrt land in double however
;; their operands were written -- which under one numeric type is just
;; that type.
(define (numeric-resulto t fixed)
  (case (numeric-mode)
    [(unified) (== t 'num)]
    [else (== t fixed)]))

(define (widen-o a b c)
  (case (numeric-mode)
    [(unified) (fresh () (== a 'num) (== b 'num) (== c 'num))]
    [else
     (conde
       ((== a 'int)    (== b 'int)    (== c 'int))
       ((== a 'int)    (== b 'double) (== c 'double))
       ((== a 'double) (== b 'int)    (== c 'double))
       ((== a 'double) (== b 'double) (== c 'double)))]))

;; ------------------------------------------------------------ environment

(define (lookupo gamma x t)
  (fresh ()
    (symbolo x)
    (conde
      ;; let-bound: re-derive, so each use gets its own variables
      ((fresh (e gamma^ rest)
         (== `((,x poly ,e ,gamma^) . ,rest) gamma)
         (!-o gamma^ e t)))
      ((fresh (rest)
         (== `((,x : ,t) . ,rest) gamma)))
      ((fresh (y d rest)
         (== `((,y . ,d) . ,rest) gamma)
         (=/= x y)
         (lookupo rest x t))))))

;; A lambda list becomes environment entries and a list of parameter types.
(define (paramso params gamma0 gamma ts)
  (conde
    ((== '() params) (== '() ts) (== gamma0 gamma))
    ((fresh (x rest T trest gamma1)
       (== `(,x . ,rest) params)
       (== `(,T . ,trest) ts)
       (symbolo x)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (paramso rest gamma1 gamma trest)))))

;; A body is a sequence; its type is the type of the last form, and the
;; earlier ones only have to have one.
(define (begino gamma body type)
  (conde
    ;; internal defines: a body may open with them, and they are a letrec*
    ;; over the rest of the body -- (define (monte-carlo trials experiment)
    ;; (define (iter ...) ...) (iter ...)) is the shape.
    ((fresh (defs rest gamma1)
       (split-defineso body defs rest)
       (=/= defs '())
       (=/= rest '())
       (declareo gamma defs gamma1)
       (bodieso gamma1 defs)
       (begino gamma1 rest type)))
    ((fresh (e) (== `(,e) body) (not-defineo e) (!-o gamma e type)))
    ((fresh (e rest tignore)
       (== `(,e . ,rest) body)
       (not-defineo e)
       (=/= rest '())
       (!-o gamma e tignore)
       (begino gamma rest type)))))

(define (not-defineo e)
  (project (e) (if (and (pair? e) (eq? (car e) 'define)) fail succeed)))

;; the leading run of defines, and what follows
(define (split-defineso body defs rest)
  (project (body)
    (if (list? body)
        (let loop ((l body) (acc '()))
          (if (and (pair? l) (pair? (car l)) (eq? (caar l) 'define))
              (loop (cdr l) (cons (car l) acc))
              (fresh () (== defs (reverse acc)) (== rest l))))
        fail)))

(define (argso gamma args ts)
  (conde
    ((== '() args) (== '() ts))
    ((fresh (a arest T trest)
       (== `(,a . ,arest) args)
       (== `(,T . ,trest) ts)
       (!-o gamma a T)
       (argso gamma arest trest)))))

;; every element of a vector literal shares one type
(define (all-of-typeo gamma es T)
  (conde
    ((== '() es))
    ((fresh (e rest)
       (== `(,e . ,rest) es)
       (!-o gamma e T)
       (all-of-typeo gamma rest T)))))

;; let bindings.
;;
;; The polymorphic reading -- keep the initialiser and re-derive it at each
;; use -- is what let-polymorphism needs, and it is also what makes this
;; relation expensive: a numeric local used five times has its initialiser
;; inferred five times, and nested lets multiply. Almost every let in the
;; kernels binds a number that is used monomorphically, so the one type is
;; tried first and the re-derivation is kept as the fallback. Both readings
;; remain available; only their order changes, and with it the cost of the
;; common case.
;; 'both keeps the polymorphic reading as an alternative, which is what
;; let-polymorphism needs and what leaves a choice point at every let;
;; 'mono drops it, for measuring what those choice points cost.
(define let-mode (make-parameter 'both))

(define (letbindo gamma0 bindings gamma)
  (conde
    ((== '() bindings) (== gamma0 gamma))
    ((fresh (x e rest T gamma1)
       (== `((,x ,e) . ,rest) bindings)
       (symbolo x)
       (!-o gamma0 e T)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (letbindo gamma1 rest gamma)))
    ((fresh (x e rest gamma1)
       (== `((,x ,e) . ,rest) bindings)
       (if (eq? (let-mode) 'mono) fail succeed)
       (== `((,x ,e) . ,rest) bindings)
       (symbolo x)
       (== gamma1 `((,x poly ,e ,gamma0) . ,gamma0))
       (letbindo gamma1 rest gamma)))))

;; letrec: every name is in scope in every initialiser
(define (letrec-bindo gamma0 bindings gamma)
  (fresh ()
    (letrec-declo gamma0 bindings gamma)
    (letrec-checko gamma bindings)))

(define (letrec-declo gamma0 bindings gamma)
  (conde
    ((== '() bindings) (== gamma0 gamma))
    ((fresh (x e rest T gamma1)
       (== `((,x ,e) . ,rest) bindings)
       (symbolo x)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (letrec-declo gamma1 rest gamma)))))

(define (letrec-checko gamma bindings)
  (conde
    ((== '() bindings))
    ((fresh (x e rest T)
       (== `((,x ,e) . ,rest) bindings)
       (lookupo gamma x T)
       (!-o gamma e T)
       (letrec-checko gamma rest)))))

(define (letbind-namedo gamma0 bindings gamma ts)
  (conde
    ((== '() bindings) (== '() ts) (== gamma0 gamma))
    ((fresh (x e rest T trest gamma1)
       (== `((,x ,e) . ,rest) bindings)
       (== `(,T . ,trest) ts)
       (symbolo x)
       (!-o gamma0 e T)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (letbind-namedo gamma1 rest gamma trest)))))

;; A do loop's bindings: each variable takes the type of its initialiser,
;; and its step expression -- read in the loop's own scope, since a step
;; mentions the variables -- must have that type again.
(define (do-bindo gamma0 bindings gamma)
  (fresh (gamma1)
    (do-bind-inito gamma0 bindings gamma1)
    (== gamma1 gamma)
    (do-bind-stepo gamma1 bindings)))

(define (do-bind-inito gamma0 bindings gamma)
  (conde
    ((== '() bindings) (== gamma0 gamma))
    ((fresh (x init rest T gamma1)
       (conde
         ((fresh (step) (== `((,x ,init ,step) . ,rest) bindings)))
         ((== `((,x ,init) . ,rest) bindings)))
       (symbolo x)
       (!-o gamma0 init T)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (do-bind-inito gamma1 rest gamma)))))

(define (do-bind-stepo gamma bindings)
  (conde
    ((== '() bindings))
    ((fresh (x init step rest T)
       (== `((,x ,init ,step) . ,rest) bindings)
       (lookupo gamma x T)
       (!-o gamma step T)
       (do-bind-stepo gamma rest)))
    ((fresh (x init rest)
       (== `((,x ,init) . ,rest) bindings)
       (do-bind-stepo gamma rest)))))

;; Every form of a body has to have a type; none of them is the value.
(define (all-typedo gamma forms)
  (conde
    ((== '() forms))
    ((fresh (e rest T)
       (== `(,e . ,rest) forms)
       (!-o gamma e T)
       (all-typedo gamma rest)))))

;; cond clauses: the tests are boolean, every branch has the loop's type,
;; and else is a test that is not read as one.
(define (cond-clauseso gamma clauses type)
  (conde
    ((fresh (body)
       (== `((else . ,body)) clauses)
       (=/= body '())
       (begino gamma body type)))
    ((fresh (test body rest)
       (== `((,test . ,body) . ,rest) clauses)
       (=/= test 'else)
       (=/= body '())
       (=/= rest '())
       (!-o gamma test 'bool)
       (begino gamma body type)
       (cond-clauseso gamma rest type)))
    ;; a final clause with a test rather than an else
    ((fresh (test body)
       (== `((,test . ,body)) clauses)
       (=/= test 'else)
       (=/= body '())
       (!-o gamma test 'bool)
       (begino gamma body type)))))

;; every operand of and/or is boolean here, which is all this subset uses
(define (all-boolo gamma es)
  (conde
    ((== '() es))
    ((fresh (e rest)
       (== `(,e . ,rest) es)
       (!-o gamma e 'bool)
       (all-boolo gamma rest)))))

;; ------------------------------------------------------------- the relation

(define (!-o gamma expr type)
  (conde
    ((symbolo expr) (lookupo gamma expr type))

    ;; A literal says which of the two it is; a variable the relation is
    ;; being asked to invent only says that it is one of them.
    ((numbero expr)
     (project (expr)
       (if (and (number? expr) (eq? (numeric-mode) 'split))
           (if (and (exact? expr) (integer? expr)) (== 'int type) (== 'double type))
           (numo type))))

    ((== #t expr) (== 'bool type))
    ((== #f expr) (== 'bool type))

    ((fresh (s) (== `(quote ,s) expr) (== 'string type)))
    ((project (expr) (if (string? expr) (== 'string type) fail)))

    ;; (lambda (x ...) body ...)
    ((fresh (params body ts R gamma1)
       (== `(lambda ,params . ,body) expr)
       (== `(-> ,ts ,R) type)
       (paramso params gamma gamma1 ts)
       (=/= body '())
       (begino gamma1 body R)))

    ;; (if c t e), read for its value: the two branches agree
    ((fresh (c t e)
       (== `(if ,c ,t ,e) expr)
       (!-o gamma c 'bool)
       (!-o gamma t type)
       (!-o gamma e type)))

    ;; (if c t) with no else: nothing to agree with, so nothing is returned
    ((fresh (c t T)
       (== `(if ,c ,t) expr)
       (== 'void type)
       (!-o gamma c 'bool)
       (!-o gamma t T)))

    ;; (if c t e) in statement position, where the value is dropped and the
    ;; branches need not agree -- (if (= d 0.0) 0 (begin (set! ...) ...)) is
    ;; the shape, and it is everywhere in the kernels. This clause comes
    ;; second, so a conditional that does have a value is typed by the first.
    ((fresh (c t e T1 T2)
       (== `(if ,c ,t ,e) expr)
       (== 'void type)
       (!-o gamma c 'bool)
       (!-o gamma t T1)
       (!-o gamma e T2)))

    ;; (begin e ...)
    ((fresh (body)
       (== `(begin . ,body) expr)
       (=/= body '())
       (begino gamma body type)))

    ;; (let ((x e) ...) body ...) -- each binding polymorphic at its uses
    ((fresh (bindings body gamma1)
       (== `(let ,bindings . ,body) expr)
       (pairo-or-nullo bindings)
       (=/= body '())
       (letbindo gamma bindings gamma1)
       (begino gamma1 body type)))

    ;; (letrec ((f e) ...) body ...) -- the bindings see each other
    ((fresh (bindings body gamma1)
       (== `(letrec ,bindings . ,body) expr)
       (pairo-or-nullo bindings)
       (=/= body '())
       (letrec-bindo gamma bindings gamma1)
       (begino gamma1 body type)))

    ;; (let* ((x e) ...) body ...) -- each binding sees the ones before it,
    ;; which is what letbindo already does since it threads the environment
    ((fresh (bindings body gamma1)
       (== `(let* ,bindings . ,body) expr)
       (pairo-or-nullo bindings)
       (=/= body '())
       (letbindo gamma bindings gamma1)
       (begino gamma1 body type)))

    ;; (let name ((x e) ...) body ...) -- a loop: name is a function of the
    ;; binding types returning what the body returns
    ((fresh (name bindings body ts gamma1 gamma2 R)
       (== `(let ,name ,bindings . ,body) expr)
       (symbolo name)
       (=/= body '())
       (== type R)
       (letbind-namedo gamma bindings gamma1 ts)
       (== gamma2 `((,name : (-> ,ts ,R)) . ,gamma1))
       (begino gamma2 body R)))

    ;; (set! x e) -- assignment has no value of its own
    ((fresh (x e T)
       (== `(set! ,x ,e) expr)
       (symbolo x)
       (== 'void type)
       (lookupo gamma x T)
       (!-o gamma e T)))

    ;; (cons-stream a b): the macro is (cons a (delay b)), and it is typed
    ;; at that shape without being expanded, like the array forms.
    ((fresh (a b A B)
       (== `(cons-stream ,a ,b) expr)
       (== `(pair ,A (promise ,B)) type)
       (!-o gamma a A)
       (!-o gamma b B)))

    ;; (make-promise (lambda () e)): delay written out by hand
    ((fresh (e T)
       (== `(make-promise (lambda () ,e)) expr)
       (== `(promise ,T) type)
       (!-o gamma e T)))

    ;; delayed streams
    ((fresh (e T)
       (== `(delay ,e) expr)
       (== `(promise ,T) type)
       (!-o gamma e T)))
    ((fresh (e T)
       (== `(force ,e) expr)
       (!-o gamma e `(promise ,type))))
    ((fresh (a d A D)
       (== `(cons ,a ,d) expr)
       (== `(pair ,A ,D) type)
       (!-o gamma a A)
       (!-o gamma d D)))
    ((fresh (e A D)
       (== `(car ,e) expr)
       (== A type)
       (!-o gamma e `(pair ,A ,D))))
    ;; car and cdr over a list, which is a tuple here: the head is the first
    ;; element type and the tail is the rest of the tuple.
    ((fresh (e ts)
       (== `(car ,e) expr)
       (!-o gamma e `(list ,type . ,ts))))
    ((fresh (e T ts)
       (== `(cdr ,e) expr)
       (== `(list . ,ts) type)
       (!-o gamma e `(list ,T . ,ts))))
    ((fresh (e A D)
       (== `(cdr ,e) expr)
       (== D type)
       (!-o gamma e `(pair ,A ,D))))

    ;; ---- the array forms, typed as written -----------------------------
    ;;
    ;; These are macros, and they are deliberately not expanded first: their
    ;; shapes are what the rewrite rules match, so expanding them before the
    ;; rules run would cost the optimisation they exist to enable. They are
    ;; therefore given types of their own, at the shape the programmer wrote.
    ;;
    ;; (with-arrays ((a (d ...)) ...) body ...): each name is a vector whose
    ;; extent the declared dimensions fix; the dimensions are indices.
    ((fresh (decls body gamma1)
       (== `(with-arrays ,decls . ,body) expr)
       (=/= body '())
       (array-declso gamma decls gamma1)
       (begino gamma1 body type)))

    ;; (range-for (i n) body ...) and (range-for (i lo hi) body ...)
    ((fresh (spec body)
       (== `(range-for ,spec . ,body) expr)
       (== 'void type)
       (=/= body '())
       (range-scopeo gamma spec body)))

    ;; (range-sum (i n) e) and (range-fold ((acc init) (i n)) e)
    ((fresh (i n e gamma1)
       (== `(range-sum (,i ,n) ,e) expr)
       (symbolo i)
       (numo type)
       (indexo gamma n)
       (== gamma1 `((,i : ,(index-type)) . ,gamma))
       (!-o gamma1 e type)))
    ((fresh (acc init i n e gamma1)
       (== `(range-fold ((,acc ,init) (,i ,n)) ,e) expr)
       (symbolo acc) (symbolo i)
       (!-o gamma init type)
       (indexo gamma n)
       (== gamma1 `((,acc : ,type) (,i : ,(index-type)) . ,gamma))
       (!-o gamma1 e type)))

    ;; whole-vector forms. array-dot and array-sum reduce to a number;
    ;; array-inc!/array-dec! update in place and return nothing.
    ((fresh (u v T)
       (== `(array-dot ,u ,v) expr)
       (numo type)
       (vec-operando gamma u type)
       (vec-operando gamma v type)))
    ((fresh (u)
       (== `(array-sum ,u) expr)
       (numo type)
       (vec-operando gamma u type)))
    ;; array-inc! and array-dec! come both ways: a whole vector updated by
    ;; another, and one element addressed by its indices updated by a scalar.
    ((fresh (op u v T)
       (== `(,op ,u ,v) expr)
       (inc-dec-opo op)
       (== 'void type)
       (vec-operando gamma u T)
       (vec-operando gamma v T)))
    ((fresh (op a rest ixs e T N)
       (== `(,op ,a . ,rest) expr)
       (inc-dec-opo op)
       (symbolo a)
       (== 'void type)
       (split-lasto rest ixs e)
       (=/= ixs '())
       (lookupo gamma a `(vec ,N ,T))
       (all-indexo gamma ixs)
       (!-o gamma e T)))
    ;; (array-reduce op init u): any monoid over a vector operand
    ((fresh (f init u)
       (== `(array-reduce ,f ,init ,u) expr)
       (!-o gamma init type)
       (vec-operando gamma u type)))

    ;; array-ref and array-set! take one index per declared dimension, so
    ;; the arity is whatever the program wrote.
    ((fresh (a ixs T N)
       (== `(array-ref ,a . ,ixs) expr)
       (symbolo a)
       (=/= ixs '())
       (lookupo gamma a `(vec ,N ,type))
       (all-indexo gamma ixs)))
    ((fresh (a rest T N ixs e)
       (== `(array-set! ,a . ,rest) expr)
       (symbolo a)
       (== 'void type)
       (split-lasto rest ixs e)
       (=/= ixs '())
       (lookupo gamma a `(vec ,N ,T))
       (all-indexo gamma ixs)
       (!-o gamma e T)))

    ;; lists. type-infer-hm.scm reads (list T ...) as a tuple -- its unifier
    ;; requires the lengths to agree -- so a literal list gives one element
    ;; type per element, and list-ref at a literal index picks that one out.
    ((fresh (es ts)
       (== `(list . ,es) expr)
       (== `(list . ,ts) type)
       (listo gamma es ts)))
    ((fresh (l i ts)
       (== `(list-ref ,l ,i) expr)
       (!-o gamma l `(list . ,ts))
       (fresh (I) (!-o gamma i I) (numeric-resulto I 'int))
       (nth-o ts i type)))
    ((fresh (l ts)
       (== `(null? ,l) expr)
       (== 'bool type)
       (!-o gamma l `(list . ,ts))))
    ((fresh (l ts)
       (== `(length ,l) expr)
       (numeric-resulto type 'int)
       (!-o gamma l `(list . ,ts))))

    ;; vectors
    ((fresh (n init T N)
       (== `(make-vector ,n ,init) expr)
       (== `(vec ,N ,T) type)
       ;; A literal length is the array's extent; anything computed leaves it
       ;; open, and open is what becomes std::vector.
       (project (n) (if (and (number? n) (exact? n)) (== N n) succeed))
       (fresh (I) (!-o gamma n I) (numeric-resulto I 'int))
       (!-o gamma init T)))
    ((fresh (v i T N)
       (== `(vector-ref ,v ,i) expr)
       (== T type)
       (!-o gamma v `(vec ,N ,T))
       (fresh (I) (!-o gamma i I) (numeric-resulto I 'int))))
    ((fresh (v i e T N)
       (== `(vector-set! ,v ,i ,e) expr)
       (== 'void type)
       (!-o gamma v `(vec ,N ,T))
       (fresh (I) (!-o gamma i I) (numeric-resulto I 'int))
       (!-o gamma e T)))
    ((fresh (es T N)
       (== `(vector . ,es) expr)
       (== `(vec ,N ,T) type)
       (=/= es '())
       (project (es) (if (list? es) (== N (length es)) succeed))
       (all-of-typeo gamma es T)))

    ;; arithmetic, of any arity: (- x) negates, (+ a b c) folds, and the
    ;; wider operand wins as it would in C++.
    ((fresh (op es)
       (== `(,op . ,es) expr)
       (arith-opo op)
       (=/= es '())
       (aritho gamma es type)))
    ((fresh (op es)
       (== `(,op . ,es) expr)
       (compare-opo op)
       (== 'bool type)
       (=/= es '())
       (all-numerico gamma es)))
    ;; division always lands in the wider tower, as (/ 1 2) does in Scheme,
    ;; and (/ x) is one over x
    ((fresh (es)
       (== `(/ . ,es) expr)
       (=/= es '())
       (numeric-resulto type 'double)
       (all-numerico gamma es)))
    ((fresh (op e T)
       (== `(,op ,e) expr)
       (unary-num-opo op)
       (!-o gamma e T)
       (numo T)
       (== T type)))
    ((fresh (op e T)
       (== `(,op ,e) expr)
       (real-opo op)
       (numeric-resulto type 'double)
       (!-o gamma e T)
       (numo T)))
    ((fresh (e1 e2)
       (== `(atan ,e1 ,e2) expr)
       (numeric-resulto type 'double)
       (all-numerico gamma (list e1 e2))))
    ((fresh (e1 e2)
       (== `(expt ,e1 ,e2) expr)
       (numeric-resulto type 'double)
       (all-numerico gamma (list e1 e2))))
    ((fresh (e T)
       (== `(zero? ,e) expr)
       (== 'bool type)
       (!-o gamma e T)
       (numo T)))

    ;; printing
    ((fresh (e T)
       (== `(display ,e) expr)
       (== 'void type)
       (!-o gamma e T)))
    ((== '(newline) expr) (== 'void type))

    ;; (do ((v init step) ...) (test result ...) body ...)
    ((fresh (bindings test results body gamma1)
       (== `(do ,bindings (,test . ,results) . ,body) expr)
       (do-bindo gamma bindings gamma1)
       (!-o gamma1 test 'bool)
       (all-typedo gamma1 body)
       (conde
         ((== '() results) (== 'void type))
         ((=/= results '()) (begino gamma1 results type)))))

    ;; (cond (test e ...) ... (else e ...))
    ((fresh (clauses)
       (== `(cond . ,clauses) expr)
       (=/= clauses '())
       (cond-clauseso gamma clauses type)))

    ((fresh (es)
       (== `(and . ,es) expr) (== 'bool type) (=/= es '()) (all-boolo gamma es)))
    ((fresh (es)
       (== `(or . ,es) expr) (== 'bool type) (=/= es '()) (all-boolo gamma es)))
    ((fresh (e)
       (== `(not ,e) expr) (== 'bool type) (!-o gamma e 'bool)))

    ((fresh (op e1 e2 T1 T2)
       (== `(,op ,e1 ,e2) expr)
       (conde ((== op 'max)) ((== op 'min)))
       (!-o gamma e1 T1)
       (!-o gamma e2 T2)
       (widen-o T1 T2 type)))

    ;; application, last so that the special forms above are tried first
    ((fresh (f args ts)
       (== `(,f . ,args) expr)
       (not-special-formo f)
       (!-o gamma f `(-> ,ts ,type))
       (argso gamma args ts)))))

;; ---- helpers for the array forms ----

;; The index type: int when widths are separate, the one numeric type when
;; they are not.
(define (index-type) (if (eq? (numeric-mode) 'unified) 'num 'int))
(define (indexo gamma e) (fresh (I) (!-o gamma e I) (numeric-resulto I 'int)))
(define (all-indexo gamma es)
  (conde
    ((== '() es))
    ((fresh (e rest) (== `(,e . ,rest) es) (indexo gamma e) (all-indexo gamma rest)))))

;; (with-arrays ((a (d ...)) ...) ...): a is a vector of numbers, and the
;; dimensions are indices. The extent stays open -- the product of the
;; dimensions is not a literal in general -- which is the std::vector case.
(define (array-declso gamma0 decls gamma)
  (conde
    ((== '() decls) (== gamma0 gamma))
    ((fresh (a dims rest N T)
       (== `((,a ,dims) . ,rest) decls)
       (symbolo a)
       (all-indexo gamma0 dims)
       (lookupo gamma0 a `(vec ,N ,T))
       (numo T)
       (array-declso gamma0 rest gamma)))))

;; (range-for (i n) ...) and (range-for (i lo hi) ...)
(define (range-scopeo gamma spec body)
  (fresh (i gamma1)
    (conde
      ((fresh (n) (== `(,i ,n) spec) (indexo gamma n)))
      ((fresh (lo hi) (== `(,i ,lo ,hi) spec) (indexo gamma lo) (indexo gamma hi))))
    (symbolo i)
    (== gamma1 `((,i : ,(index-type)) . ,gamma))
    (all-typedo gamma1 body)))

;; a vector operand: a name, a row of a declared array, a slice of either,
;; or a scaled one. T is the element type either way.
(define (vec-operando gamma opnd T)
  (conde
    ((fresh (N) (symbolo opnd) (lookupo gamma opnd `(vec ,N ,T))))
    ((fresh (a j) (== `(row ,a ,j) opnd) (indexo gamma j) (vec-operando gamma a T)))
    ((fresh (u lo hi) (== `(slice ,u ,lo ,hi) opnd)
            (indexo gamma lo) (indexo gamma hi) (vec-operando gamma u T)))
    ((fresh (u lo hi st) (== `(slice ,u ,lo ,hi ,st) opnd)
            (indexo gamma lo) (indexo gamma hi) (indexo gamma st)
            (vec-operando gamma u T)))
    ((fresh (c u) (== `(scale ,c ,u) opnd) (!-o gamma c T) (vec-operando gamma u T)))
    ((fresh (x i) (== `(box ,x ,i) opnd) (indexo gamma i) (vec-operando gamma x T)))
    ;; (sub a r0 r1 c0 c1): the rectangle, numpy's a[r0:r1, c0:c1]
    ((fresh (a bounds)
       (== `(sub ,a . ,bounds) opnd)
       (=/= bounds '())
       (all-indexo gamma bounds)
       (vec-operando gamma a T)))
    ;; arithmetic over whole vectors, elementwise: two vectors add and
    ;; subtract, and a vector scales by a number on either side.
    ((fresh (op u v)
       (== `(,op ,u ,v) opnd)
       (conde ((== op '+)) ((== op '-)))
       (vec-operando gamma u T)
       (vec-operando gamma v T)))
    ((fresh (u c)
       (== `(* ,u ,c) opnd)
       (vec-operando gamma u T)
       (!-o gamma c T)))
    ((fresh (c u)
       (== `(* ,c ,u) opnd)
       (!-o gamma c T)
       (vec-operando gamma u T)))))

(define (inc-dec-opo op)
  (conde ((== op 'array-inc!)) ((== op 'array-dec!))))

;; the leading elements and the last, for array-set!'s indices and value
(define (split-lasto l front last)
  (project (l)
    (if (and (list? l) (pair? l))
        (fresh () (== front (reverse (cdr (reverse l)))) (== last (car (reverse l))))
        fail)))

;; the operands of an n-ary arithmetic form, folded by width
(define (aritho gamma es type)
  (conde
    ((fresh (e) (== `(,e) es) (!-o gamma e type) (numo type)))
    ((fresh (e rest T R)
       (== `(,e . ,rest) es)
       (=/= rest '())
       (!-o gamma e T)
       (aritho gamma rest R)
       (widen-o T R type)))))

(define (all-numerico gamma es)
  (conde
    ((== '() es))
    ((fresh (e rest T)
       (== `(,e . ,rest) es)
       (!-o gamma e T)
       (numo T)
       (all-numerico gamma rest)))))

(define (listo gamma es ts)
  (conde
    ((== '() es) (== '() ts))
    ((fresh (e rest T trest)
       (== `(,e . ,rest) es)
       (== `(,T . ,trest) ts)
       (!-o gamma e T)
       (listo gamma rest trest)))))

;; list-ref at a literal index, which is the only one a tuple can answer
(define (nth-o ts i type)
  (project (i)
    (if (and (number? i) (exact? i) (>= i 0))
        (let loop ((n i) (l ts))
          (fresh (a d)
            (== `(,a . ,d) l)
            (if (zero? n) (== a type) (loop (- n 1) d))))
        fail)))

(define (real-opo op)
  (conde ((== op 'sqrt)) ((== op 'sin)) ((== op 'cos)) ((== op 'tan))
         ((== op 'exp)) ((== op 'log)) ((== op 'atan))
         ((== op 'exact->inexact))))

(define (pairo-or-nullo x)
  (conde ((== '() x)) ((fresh (a d) (== `(,a . ,d) x)))))

(define (arith-opo op)
  (conde ((== op '+)) ((== op '-)) ((== op '*)) ((== op 'remainder))
         ((== op 'modulo)) ((== op 'quotient))))

(define (compare-opo op)
  (conde ((== op '<)) ((== op '>)) ((== op '<=)) ((== op '>=)) ((== op '=))))

(define (unary-num-opo op)
  (conde ((== op 'add1)) ((== op 'sub1)) ((== op 'abs))))

;; Everything the relation gives its own clause: an application may not be
;; one of these, or the two readings would both succeed.
(define special-forms
  '(lambda if begin let set! delay force cons car cdr
    make-vector vector-ref vector-set! vector
    + - * / remainder modulo quotient < > <= >= =
    add1 sub1 abs sqrt zero? display newline quote define
    do cond else and or not max min let* letrec cons-stream define-macro
    make-promise
    list list-ref null? length
    sin cos tan exp log atan expt exact->inexact
    with-arrays range-for range-fold range-sum
    array-dot array-sum array-ref array-set! array-inc! array-dec!
    array-reduce row slice scale box sub))

;; Running forwards the head of an application is a ground symbol, so this
;; is one memq and no constraint at all. Running backwards it is a variable,
;; and then the disequalities are what keeps the enumeration off the special
;; forms -- but there is one application node per call in a kernel, and
;; forty-eight disequalities apiece is a constraint store the unifier then
;; rechecks at every step. Paying that only in the direction that needs it
;; is most of what makes a real program reachable.
(define (not-special-formo f)
  (project (f)
    (cond
      [(symbol? f) (if (memq f special-forms) fail succeed)]
      [(pair? f) succeed]
      [else
       (let loop ([fs special-forms])
         (cond
           [(null? fs) succeed]
           [else (fresh () (=/= f (car fs)) (loop (cdr fs)))]))])))

;; ---------------------------------------------------------------- programs

;; A define extends the environment. A function's own name is in scope
;; while its body is read, so it may call itself; the recursion is
;; monomorphic, which is what algorithm W does with a letrec too.
;; A list of fresh type variables, one per parameter.
(define (freshso params ts)
  (conde
    ((== '() params) (== '() ts))
    ((fresh (p prest T trest)
       (== `(,p . ,prest) params)
       (== `(,T . ,trest) ts)
       (freshso prest trest)))))

;; Every name a form defines, bound to a fresh type. Definitions are read
;; as a group, so one may call another written after it -- which is what
;; Scheme means at the top of a file and inside a body, and what a file
;; like test-scm-code/comp-test.scm relies on.
(define (declareo gamma0 forms gamma)
  (conde
    ((== '() forms) (== gamma0 gamma))
    ;; a define-macro defines syntax, not a value: the forms it introduces
    ;; are typed at their own shapes (cons-stream, delay, the array forms),
    ;; so the definition itself is passed over
    ((fresh (rest r1)
       (== `((define-macro . ,r1) . ,rest) forms)
       (declareo gamma0 rest gamma)))
    ((fresh (f params body rest ts R gamma1)
       (== `((define (,f . ,params) . ,body) . ,rest) forms)
       (symbolo f)
       (freshso params ts)
       (== gamma1 `((,f : (-> ,ts ,R)) . ,gamma0))
       (declareo gamma1 rest gamma)))
    ((fresh (x e rest T gamma1)
       (== `((define ,x ,e) . ,rest) forms)
       (symbolo x)
       (== gamma1 `((,x : ,T) . ,gamma0))
       (declareo gamma1 rest gamma)))))

;; and then every body, against the environment they all share
(define (bodieso gamma forms)
  (conde
    ((== '() forms))
    ((fresh (rest r1)
       (== `((define-macro . ,r1) . ,rest) forms)
       (bodieso gamma rest)))
    ((fresh (f params body rest ts R gamma1)
       (== `((define (,f . ,params) . ,body) . ,rest) forms)
       (lookupo gamma f `(-> ,ts ,R))
       (paramso params gamma gamma1 ts)
       (=/= body '())
       (condu ((begino gamma1 body R)))
       (bodieso gamma rest)))
    ((fresh (x e rest T)
       (== `((define ,x ,e) . ,rest) forms)
       (lookupo gamma x T)
       (condu ((!-o gamma e T)))
       (bodieso gamma rest)))))

(define (defineo gamma0 form gamma)
  (conde
    ((fresh (f params body ts R gamma1 gamma2)
       (== `(define (,f . ,params) . ,body) form)
       (symbolo f)
       (=/= body '())
       (== gamma `((,f : (-> ,ts ,R)) . ,gamma0))
       (paramso params gamma gamma2 ts)
       (begino gamma2 body R)))
    ((fresh (x e T)
       (== `(define ,x ,e) form)
       (symbolo x)
       (!-o gamma0 e T)
       (== gamma `((,x : ,T) . ,gamma0))))))

;; The two shapes need no marker to be told apart: (define x e) requires x
;; to be a symbol, which symbolo enforces, and a function definition has a
;; pair there instead.

;; Each definition is typed once and committed to.
;;
;; Without the commitment a definition that fails to type sends the search
;; back into every definition before it, to try their other readings, and
;; the cost of a program multiplies rather than adds -- measured at about
;; five times per definition on the covariance lasso kernel, which puts a
;; six-definition file out of reach. Committing is not free: the first
;; typing found for a definition need not be its most general, so a later
;; use can fail against a type that a second reading would have satisfied.
;; The relation without the commitment is still there, as programo/complete.
(define (programo gamma0 forms gamma)
  (fresh ()
    (declareo gamma0 forms gamma)
    (bodieso gamma forms)))

(define (programo/complete gamma0 forms gamma)
  (conde
    ((== '() forms) (== gamma0 gamma))
    ((fresh (form rest gamma1)
       (== `(,form . ,rest) forms)
       (defineo gamma0 form gamma1)
       (programo/complete gamma1 rest gamma)))))

;; -------------------------------------------------------------- the front

;; The type of a closed expression, or #f when it has none.
(define (infer-type expr [gamma '()])
  (let ([r (run 1 (T) (!-o gamma expr T))])
    (if (null? r) #f (car r))))

;; Every type it finds, up to n of them: where the answer is not unique the
;; relation says so instead of picking.
(define (infer-type* expr [n 5] [gamma '()])
  (run n (T) (!-o gamma expr T)))

;; ---------------------------------------------- from ==> to nominal types
;;
;; What the emitter can write is a nominal recursive type; what this pass
;; derives is a structural one, (==> x B) with x free in B, possibly rolled
;; at any point of its cycle. The conversion rules, in order:
;;
;;   1. Canonicalise the roll. The two spellings of a stream
;;
;;        (==> x (pair A (promise x)))            rolled at the pair
;;        (pair A (==> y (promise (pair A y))))   rolled at the promise
;;
;;      are the same infinite tree, so the promise-rolled form is rewritten
;;      to the pair-rolled one and every equal cycle gets one spelling.
;;
;;   2. Name the known shape: (==> x (pair A (promise x))) with x guarded
;;      under the promise is exactly (scm2cpp-stream A), the nominal type
;;      the emitter renders as scm2cpp::stream_cell<A>.
;;
;;   3. Guardedness decides the rest. In an (==> x B) that is not a stream,
;;      every occurrence of x must sit under a promise or a function type:
;;      those positions are std::function indirections in C++, so a fresh
;;      nominal struct could hold them, and the annotation is left intact
;;      for an emitter that introduces one. An occurrence in a bare value
;;      position -- (==> x (pair num x)), a circular list as data -- has no
;;      C++ value of finite size, and the conversion refuses it: such a
;;      value needs laziness or pointers, and the subset has no GC.
;;
(define (type->nominal t)
  (let conv ([t t])
    (cond
      [(and (pair? t) (eq? (car t) '==>))
       (let* ([x (cadr t)] [b (conv (caddr t))])
         (cond
           ;; rule 2: the stream shape
           [(and (pair? b) (eq? (car b) 'pair)
                 (pair? (caddr b)) (eq? (car (caddr b)) 'promise)
                 (equal? (cadr (caddr b)) x))
            (list 'scm2cpp-stream (cadr b))]
           ;; rule 3: guarded elsewhere stays annotated, unguarded refuses
           [(rec-guarded? x b) (list '==> x b)]
           [else (error 'type->nominal
                        "unguarded recursion ~a: a value of this type has no finite size"
                        (list '==> x b))]))]
      ;; rule 1: a promise-rolled stream, seen from outside the cycle
      [(and (pair? t) (eq? (car t) 'pair)
            (let ([d (caddr t)])
              (and (pair? d) (eq? (car d) '==>)
                   (let ([b (caddr d)])
                     (and (pair? b) (eq? (car b) 'promise)
                          (pair? (cadr b)) (eq? (car (cadr b)) 'pair)
                          (equal? (cadr (cadr b)) (cadr t))
                          (equal? (caddr (cadr b)) (cadr d)))))))
       (list 'scm2cpp-stream (conv (cadr t)))]
      [(pair? t)
       (let ([t (cons (conv (car t)) (conv (cdr t)))])
         ;; rule 1 again, after the parts are converted: the once-unrolled
         ;; stream, (pair A (promise (scm2cpp-stream A))), is the stream --
         ;; a stream_cell is nothing else -- so it takes the same name.
         (if (and (eq? (car t) 'pair)
                  (pair? (caddr t)) (eq? (car (caddr t)) 'promise)
                  (equal? (cadr (caddr t)) (list 'scm2cpp-stream (cadr t))))
             (cadr (caddr t))
             t))]
      [else t])))

;; is every occurrence of x in b under a promise or a function arrow?
(define (rec-guarded? x b)
  (let walk ([t b] [guarded #f])
    (cond
      [(equal? t x) guarded]
      [(and (pair? t) (memq (car t) '(promise ->)))
       (andmap (lambda (u) (walk u #t)) (cdr t))]
      [(pair? t) (andmap (lambda (u) (walk u guarded)) t)]
      [else #t])))

;; The types a sequence of defines gives its names, newest first, or #f if
;; the program has none. This is the shape the translator wants: one entry
;; per top-level name.
(define (infer-program forms [gamma0 '()])
  (let ([r (run 1 (G) (programo gamma0 forms G))])
    (if (null? r)
        #f
        (for/list ([e (car r)] #:when (and (pair? e) (eq? (cadr e) ':)))
          (cons (car e) (caddr e))))))

;; Backwards: terms of a given type. This is the direction algorithm W does
;; not have, and the reason the proposer tools want a relation here.
(define (inhabitants type [n 5] [gamma '()])
  (run n (e) (!-o gamma e type)))

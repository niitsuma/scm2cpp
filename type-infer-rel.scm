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
;;;;   (vec T)                        vector, element type only
;;;;   (pair A B)                     cons cell
;;;;   (promise T)                    what delay makes and force takes
;;;;   (==> x T)                      T, with x inside it standing for T
;;;;
;;;; The environment is an association list of (x : T) and, for a let-bound
;;;; name, (x poly e gamma): its type is re-derived at each use, which is how
;;;; let-polymorphism is had relationally -- the derivation supplies fresh
;;;; variables every time.
;;;;
;;;; What it is good for, and what it is not.
;;;;
;;;; A small term it handles either way and quickly: this is the scale the
;;;; proposer tools work at, where a rewrite is a few lines and the question
;;;; is whether it has the type its context demands, or what terms do.
;;;;
;;;; A whole kernel it does not. Typing the six definitions of
;;;; examples/kernel-only/lasso-cov.scm costs about five times as much per
;;;; definition added -- 2ms, 11s, 27s, 133s -- and does not finish. Four
;;;; things were measured and are not the cause: binding let monomorphically
;;;; first, collapsing the numeric tower, committing to one typing per
;;;; definition, and keeping the special-form test out of the constraint
;;;; store each bought half or nothing. What is left is the search itself,
;;;; which re-derives shared subterms because nothing remembers them, and
;;;; the remedy for that is tabling rather than another clause order.
;;;;
;;;; One correctness note, which matters more than the speed. In 'split mode
;;;; the numeric tower is a choice, so the relation returns a typing rather
;;;; than the principal one: soft-threshold comes back as (-> (int double)
;;;; double), which is consistent but too narrow for its callers, and
;;;; committing to it makes them fail. Arithmetic has to unify rather than
;;;; branch for the answer to be principal, which is what 'unified does,
;;;; leaving the int-against-double decision where the emitter already makes
;;;; it.

(provide numeric-mode !-o programo programo/complete infer-type infer-type* infer-program inhabitants
         numo widen-o base-type?)

(require "vendor/mk-recursive/mk.scm")

;; ---------------------------------------------------------------- numbers

(define (base-type? t) (memq t '(int double bool void string)))

;; How the numeric tower is modelled during inference.
;;
;;   'split    int and double are separate, and arithmetic widens. This is
;;             what the C++ needs to know, but each arithmetic node forks
;;             four ways and a kernel with seventy of them cannot be
;;             searched.
;;   'unified  one numeric type. Arithmetic then unifies instead of
;;             branching, and the int-against-double decision is left to
;;             the pass that already makes it for the emitter.
(define numeric-mode (make-parameter 'split))

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
    ((fresh (e) (== `(,e) body) (!-o gamma e type)))
    ((fresh (e rest tignore)
       (== `(,e . ,rest) body)
       (=/= rest '())
       (!-o gamma e tignore)
       (begino gamma rest type)))))

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
       (symbolo x)
       (== gamma1 `((,x poly ,e ,gamma0) . ,gamma0))
       (letbindo gamma1 rest gamma)))))

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
    ((fresh (e A D)
       (== `(cdr ,e) expr)
       (== D type)
       (!-o gamma e `(pair ,A ,D))))

    ;; vectors
    ((fresh (n init T)
       (== `(make-vector ,n ,init) expr)
       (== `(vec ,T) type)
       (fresh (I) (!-o gamma n I) (numeric-resulto I 'int))
       (!-o gamma init T)))
    ((fresh (v i T)
       (== `(vector-ref ,v ,i) expr)
       (== T type)
       (!-o gamma v `(vec ,T))
       (fresh (I) (!-o gamma i I) (numeric-resulto I 'int))))
    ((fresh (v i e T)
       (== `(vector-set! ,v ,i ,e) expr)
       (== 'void type)
       (!-o gamma v `(vec ,T))
       (fresh (I) (!-o gamma i I) (numeric-resulto I 'int))
       (!-o gamma e T)))
    ((fresh (es T)
       (== `(vector . ,es) expr)
       (== `(vec ,T) type)
       (=/= es '())
       (all-of-typeo gamma es T)))

    ;; arithmetic: the wider operand wins, as it would in C++
    ((fresh (op e1 e2 T1 T2)
       (== `(,op ,e1 ,e2) expr)
       (arith-opo op)
       (!-o gamma e1 T1)
       (!-o gamma e2 T2)
       (widen-o T1 T2 type)))
    ((fresh (op e1 e2 T1 T2)
       (== `(,op ,e1 ,e2) expr)
       (compare-opo op)
       (== 'bool type)
       (!-o gamma e1 T1)
       (!-o gamma e2 T2)
       (numo T1)
       (numo T2)))
    ;; division always lands in the wider tower, as (/ 1 2) does in Scheme
    ((fresh (e1 e2 T1 T2)
       (== `(/ ,e1 ,e2) expr)
       (numeric-resulto type 'double)
       (!-o gamma e1 T1)
       (!-o gamma e2 T2)
       (numo T1)
       (numo T2)))
    ((fresh (op e T)
       (== `(,op ,e) expr)
       (unary-num-opo op)
       (!-o gamma e T)
       (numo T)
       (== T type)))
    ((fresh (e T)
       (== `(sqrt ,e) expr)
       (numeric-resulto type 'double)
       (!-o gamma e T)
       (numo T)))
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
    do cond else and or not max min))

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
  (conde
    ((== '() forms) (== gamma0 gamma))
    ((fresh (form rest gamma1)
       (== `(,form . ,rest) forms)
       (condu ((defineo gamma0 form gamma1)))
       (programo gamma1 rest gamma)))))

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

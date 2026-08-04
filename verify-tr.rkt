#lang racket
;;;; Check the front end's inference against Typed Racket.
;;;;
;;;;   racket verify-tr.rkt [-t scm2c.typ] [--keep] prog.scm
;;;;
;;;; The Hindley-Milner pass and the emitter are one implementation; a bug
;;;; there produces wrong C++ with no independent witness. This tool turns
;;;; the inferred types into Typed Racket annotations, writes the program
;;;; out as a typed/racket module, and lets a second, unrelated type
;;;; checker read it. A binding pair misread as an application, an
;;;; argument list of the wrong length, a vector where a scalar was meant
;;;; -- Typed Racket rejects all of these outright.
;;;;
;;;; The check runs at the Real level of the numeric tower, deliberately.
;;;; Typed Racket types (* 2.5 i) as Real, not Flonum, and it is right:
;;;; Racket's exact zero survives multiplication by a float, so the
;;;; Flonum level genuinely does not describe this program's Racket
;;;; semantics. Real absorbs the difference. What is verified is the
;;;; structure -- what is a function, what it takes, what is a vector and
;;;; of what -- and the int-against-double decision stays with the HM
;;;; pass, which the C++ needs it from.
;;;;
;;;; Functions whose inferred signature still contains an unresolved type
;;;; variable are the subset's polymorphism; they become template
;;;; functions in C++ and have no ground Typed Racket type here. They are
;;;; emitted with every unresolved position mapped to Real -- the common
;;;; case is a numeric parameter nothing constrained -- and reported, so
;;;; a failure inside one is read with that in mind.

(require racket/list
         "type-infer-match.scm"
         (only-in "scheme-macro-parser.rkt" scheme-code-string-macro-expand))

;;;; ---- command line ----------------------------------------------------

(define type-file (make-parameter "scm2c.typ"))
(define keep-file (make-parameter #f))

(define source-file
  (command-line
   #:program "verify-tr"
   #:once-each
   [("-t" "--type-file") tf "type annotation file" (type-file tf)]
   [("--keep") "keep the generated typed module beside the source"
               (keep-file #t)]
   #:args (filename) filename))

;;;; ---- run the front end ------------------------------------------------

(define expanded
  (call-with-input-string
   (string-append "(begin "
                  (scheme-code-string-macro-expand (file->string source-file))
                  ")")
   read))

(define-values (env ret unknowns expr-alpha alpha-inv free-inv)
  (infer-type-from-org-expr expanded))

(define (vtype v)
  (let ([kv (assq v env)]) (and kv (cdr kv))))

;;;; ---- mapping inferred types to Typed Racket --------------------------

(define (base-name sym)
  (let ([m (regexp-match #px"^([A-Za-z]+)" (symbol->string sym))])
    (and m (cadr m))))

;; #t when the type resolved to something a ground TR type exists for.
(define (settled? t)
  (cond [(pair? t) (andmap settled? (if (eq? (car t) 'lambda)
                                        (cons (last t) (cadr t))
                                        (cdr t)))]
        [(symbol? t)
         (member (base-name t)
                 '("Double" "Float" "Number" "Int" "Bool" "Void"
                   "String" "Char"))]
        [else #f]))

;; The Real-level rendering. Unresolved variables become Real: the usual
;; unconstrained thing in this subset is a number.
(define (tr-type t)
  (cond
    [(pair? t)
     (case (car t)
       [(lambda)
        ;; Nullary is ambiguous in this subset: the same inferred type
        ;; covers a plain thunk and a promise (the pre-pass writes delay
        ;; as make-promise of a thunk). The union covers both, and it is
        ;; exactly scm-force's domain.
        (if (null? (cadr t))
            (let ([r (tr-type (last t))])
              `(U (Promise ,r) (-> ,r)))
            `(-> ,@(map tr-type (cadr t)) ,(tr-type (last t))))]
       [(make-vector vector) `(Vectorof ,(tr-type (caddr t)))]
       [(make-list list) `(Listof ,(tr-type (caddr t)))]
       [else 'Any])]
    [(symbol? t)
     (case (base-name t)
       [("Double" "Float" "Number") 'Real]
       [("Int") 'Integer]
       [("Bool") 'Boolean]
       [("Void") 'Void]
       [("String") 'String]
       [("Char") 'Char]
       [else 'Real])]
    [else 'Any]))

;; A do loop's variable may be stepped -- (i 0 (+ i 1)) -- or not.
(define (do-binding b wk)
  (match b
    [(list v init step ...)
     `(,v : ,(tr-type (vtype v)) ,(wk init) ,@(map wk step))]))

;;;; ---- rewriting the tree for the typed module -------------------------
;;;; Bindings get annotations from the inference; the few places where
;;;; Typed Racket's own reading differs from the subset's go through
;;;; shims, instantiated explicitly because mutable vectors are invariant
;;;; -- (Vectorof Flonum) is not a (Vectorof Real), so the element type
;;;; must be said, not inferred.

(define (walk e [loop-names '()])
  (define (w x) (walk x loop-names))
  (match e
    [`(quote ,_) e]
    ;; delay: the runtime's promise memoises a thunk; the shim gives that
    ;; the type (Promise T).
    [`(delay ,body ...)
     (let ([t (tr-type (infer-of `(begin ,@body)))])
       `((inst scm-make-promise ,t) (lambda () ,@(map w body))))]
    [`(make-promise ,th)
     ;; The alpha pass wraps an anonymous lambda in a let returning it;
     ;; annotating that binding would give it the thunk-or-promise union,
     ;; which the shim's (-> a) parameter does not take. Hand the shim
     ;; the bare lambda.
     (let ([t (thunk-result-type th)]
	   [bare (match th
		   [`(let ((,l (lambda () ,body ...))) ,l2)
		    #:when (eq? l l2)
		    `(lambda () ,@(map w body))]
		   [_ (w th)])])
       `((inst scm-make-promise ,t) ,bare))]
    [`(force ,x)
     `(scm-force ,(w x))]
    [`(sqrt ,x) `(scm-sqrt ,(w x))]
    [`(log ,x) `(scm-log ,(w x))]
    [`(expt ,x ,y) `(scm-expt ,(w x) ,(w y))]
    [`(vector ,e1 ,es ...)
     (let ([t (tr-type (infer-of e1))])
       `((inst scm-vlit ,t) ,@(map w (cons e1 es))))]
    [`(let ,(? symbol? name) ((,vs ,is) ...) ,body ...)
     ;; The recursion below must know NAME is a loop, not a thunk: its
     ;; nullary type would otherwise send the recursive call through
     ;; scm-force. An unsettled return -- the loop's value unused --
     ;; annotates as Void, which is what an else-less cond tail yields.
     (let* ([ft (vtype name)]
	    [ret (if (and (pair? ft) (eq? (car ft) 'lambda))
		     (if (settled? (last ft)) (tr-type (last ft)) 'Void)
		     'Any)]
	    [inner (cons name loop-names)])
       `(let ,name : ,ret
	  ,(map (lambda (v i) `(,v : ,(tr-type (vtype v)) ,(walk i loop-names))) vs is)
	  ,@(map (lambda (b) (walk b inner)) body)))]
    [`(let ((,vs ,is) ...) ,body ...)
     `(let ,(map (lambda (v i) `(,v : ,(tr-type (vtype v)) ,(w i))) vs is)
        ,@(map w body))]
    [`(let* ((,vs ,is) ...) ,body ...)
     `(let* ,(map (lambda (v i) `(,v : ,(tr-type (vtype v)) ,(w i))) vs is)
        ,@(map w body))]
    [`(letrec ((,vs ,is) ...) ,body ...)
     `(letrec ,(map (lambda (v i) `(,v : ,(tr-type (vtype v)) ,(w i))) vs is)
        ,@(map w body))]
    [`(do ,bindings (,test ,res ...) ,body ...)
     `(do : ,(if (null? res) 'Void (tr-type (infer-of (car res))))
          ,(map (lambda (b) (do-binding b w)) bindings)
          (,(w test) ,@(map w res))
        ,@(map w body))]
    ;; An internal define needs its annotation too, or Typed Racket
    ;; reports insufficient information for any recursive use. An
    ;; internal begin splices in a definition context, carrying the
    ;; annotation alongside.
    [`(define (,f ,ps ...) ,body ...)
     (let ([ft (vtype f)])
       (if (and (pair? ft) (eq? (car ft) 'lambda))
	   `(begin (: ,f ,(tr-type ft))
		   (define (,f ,@ps) ,@(map w body)))
	   `(define (,f ,@ps) ,@(map w body))))]
    [`(define ,(? symbol? x) ,init)
     (let ([t (vtype x)])
       (if t
	   `(begin (: ,x ,(tr-type t)) (define ,x ,(walk init)))
	   `(define ,x ,(walk init))))]
    ;; A direct call of a nullary-typed variable: the union type that
    ;; covers thunk-or-promise cannot be applied, and scm-force is the
    ;; eliminator for exactly that union.
    [(list (? symbol? f))
     #:when (and (not (memq f loop-names))
		 (let ([t (vtype f)])
		   (and (pair? t) (eq? (car t) 'lambda) (null? (cadr t)))))
     `(scm-force ,f)]
    [(? list?) (map w e)]
    [_ e]))

;; The inferred type of an arbitrary subexpression is not in the exported
;; environment, which is keyed by variables. Two cheap approximations
;; cover the uses here: a variable is looked up, a float literal is Real,
;; an int literal Integer, and anything else falls back to Real -- which
;; is where the Real-level check lives anyway.
(define (infer-of e)
  (cond [(symbol? e) (or (vtype e) 'Real-fallback)]
        [(exact-integer? e) 'Int-literal]
        [(real? e) 'Double-literal]
        [(not (pair? e)) 'Real-fallback]
        [(memq (car e) '(begin let let*)) (infer-of (last e))]
        [(memq (car e) '(set! vector-set! set-car! set-cdr! display newline))
         'Void-literal]
        [(memq (car e) '(make-vector make-list))
         `(make-vector unsized ,(infer-of (caddr e)))]
        ;; Arithmetic keeps Integer only when every operand does; one
        ;; float pulls the whole expression to Real, matching both the
        ;; front end's widening and Typed Racket's own reading.
        [(memq (car e) '(+ - *))
         (let ([ts (map infer-of (cdr e))])
           (if (andmap (lambda (t) (and (symbol? t)
                                        (equal? (base-name t) "Int")))
                       ts)
               'Int-literal 'Double-literal))]
        [(memq (car e) '(quotient remainder modulo vector-length)) 'Int-literal]
        [(memq (car e) '(/ exp log sqrt sin cos tan max min abs floor))
         'Double-literal]
        [(and (symbol? (car e)) (vtype (car e)))
         (let ([ft (vtype (car e))])
           (if (and (pair? ft) (eq? (car ft) 'lambda)) (last ft) 'Real-fallback))]
        [else 'Real-fallback]))

(define (thunk-result-type th)
  (match th
    [`(lambda () ,body ...) (tr-type (infer-of `(begin ,@body)))]
    ;; Alpha conversion wraps an anonymous lambda in a let that returns it.
    [`(let ((,l (lambda () ,body ...))) ,l2)
     #:when (eq? l l2)
     (tr-type (infer-of `(begin ,@body)))]
    [_ 'Real]))

;;;; ---- emitting the module ---------------------------------------------

(define shims
  '((: scm-make-promise (All (a) (-> (-> a) (Promise a))))
    (define (scm-make-promise th) (delay (th)))
    (: scm-force (All (a) (-> (U (Promise a) (-> a)) a)))
    (define (scm-force x) (if (promise? x) (force x) (x)))
    (: scm-vlit (All (a) (-> a * (Vectorof a))))
    (define (scm-vlit . xs) (list->vector xs))
    ;; sqrt, log and expt are Number-valued in Typed Racket, since a
    ;; negative argument goes complex. The C++ side is real throughout,
    ;; so the shims assert what the subset already assumes.
    (: scm-sqrt (-> Real Real))
    (define (scm-sqrt x) (assert (sqrt x) real?))
    (: scm-log (-> Real Real))
    (define (scm-log x) (assert (log x) real?))
    (: scm-expt (-> Real Real Real))
    (define (scm-expt x y) (assert (expt x y) real?))))

(define reported-polymorphic '())

;; Streams are a nominal recursive type on the C++ side; there is no
;; ground Typed Racket rendering here yet, so a file that uses them is
;; declared out of scope rather than reported as a disagreement.
(define (mentions-stream? t)
  (cond [(pair? t) (or (eq? (car t) 'scm2cpp-stream) (ormap mentions-stream? t))]
        [else #f]))
(when (ormap (lambda (kv) (mentions-stream? (cdr kv))) env)
  (printf "SKIP: stream types are outside this tool's scope~n")
  (exit 2))

(define (emit-form form)
  (match form
    [`(define (,f ,params ...) ,body ...)
     (let ([ft (vtype f)])
       (cond
         [(not (and (pair? ft) (eq? (car ft) 'lambda)))
          `((define (,f ,@params) ,@(map walk body)))]
         [else
          (unless (settled? ft)
            (set! reported-polymorphic (cons f reported-polymorphic)))
          `((: ,f ,(tr-type ft))
            (define (,f ,@params) ,@(map walk body)))]))]
    [`(define ,(? symbol? x) ,init)
     (let ([t (vtype x)])
       (if t
           `((: ,x ,(tr-type t)) (define ,x ,(walk init)))
           `((define ,x ,(walk init)))))]
    [_ (list (walk form))]))

(define forms
  (if (and (pair? expr-alpha) (eq? (car expr-alpha) 'begin))
      (cdr expr-alpha)
      (list expr-alpha)))

;; A (main) call at top level would RUN the program during raco make;
;; type checking does not need it, so bare top-level calls are dropped.
(define (top-level-call? f)
  (and (pair? f) (symbol? (car f)) (not (memq (car f) '(define begin)))))

(define emitted
  (append shims
          (append-map emit-form (filter (lambda (f) (not (top-level-call? f)))
                                        forms))))

(define out-path
  (if (keep-file)
      (path-replace-extension source-file "_tr.rkt")
      (build-path (find-system-path 'temp-dir)
                  (format "scm2cpp-verify-tr-~a.rkt"
                          (equal-hash-code (file->string source-file))))))

(with-output-to-file out-path #:exists 'replace
  (lambda ()
    (displayln "#lang typed/racket")
    (displayln ";; generated by verify-tr.rkt -- annotations are the HM")
    (displayln ";; pass's inference at the Real level; do not edit.")
    (for ([f emitted]) (writeln f))))

;;;; ---- run the second checker ------------------------------------------

(define-values (proc p-out p-in p-err)
  (subprocess #f #f #f (find-executable-path "raco") "make" "-v"
              (path->string out-path)))
(define err-text (port->string p-err))
(define out-text (port->string p-out))
(subprocess-wait proc)
(define code (subprocess-status proc))

;; raco make exits 0 even when compilation failed for some error classes;
;; the presence of a type-checker message is the real verdict.
(define failed?
  (or (not (zero? code))
      (regexp-match? #px"Type Checker" err-text)
      (regexp-match? #px"Type Checker" out-text)))

(unless (null? reported-polymorphic)
  (eprintf "polymorphic, checked with unresolved positions as Real: ~a~n"
           (reverse reported-polymorphic)))

(cond
  [failed?
   (printf "NG: Typed Racket disagrees with the inference~n")
   (for ([l (string-split err-text "\n")]
         #:when (or (regexp-match? #px"Type Checker" l)
                    (regexp-match? #px"expected:|given:|in:" l)))
     (printf "  ~a~n" l))
   (printf "generated module: ~a~n" out-path)
   (exit 1)]
  [else
   (printf "OK: Typed Racket agrees (Real level)~n")
   (unless (keep-file) (delete-file out-path))
   (exit 0)])

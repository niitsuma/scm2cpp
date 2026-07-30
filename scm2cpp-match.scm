#lang racket

(provide 
 scm2cpp-match-port
 scm2cpp-match-values
 scm2cpp-match-list
)

(require srfi/1)
(require srfi/14)
(require mzlib/defmacro)
(require racket/file)

(require "alist-util.scm")
(require "cl-util.scm")
(require "list-util.scm")
(require "onlisp.scm")

;(require "./cl2scm/bsort.scm")



(require "schlep-name.scm")
(require "alpha-conv.scm")
(require "type-infer-util.scm")

(require "depend-analysis.scm")
(require "rewrite-search.scm")

;; ;; type= match
;;;;(require "type-infer-match.scm")

;; ;;type= ck
(require "type-symbols.scm")


;(require "type-infer-ck.scm")
(require "type-infer-match.scm")

;; ;;  type=racklog
;(require racklog)
;(require "schelog-util.scm")
;(require "type-infer.scm")
;(require "schlep-out.scm")


(require "scm2cpp-function.scm")


(require "scheme-macro-parser.rkt")




(define cpp-function-name-correspond-alist
  '(
    (eq? . "scm2cpp::is_eq")
    (eqv? . "scm2cpp::is_eqv")
    (equal? . "scm2cpp::is_equal")
    (cons . "scm2cpp::cons")
    (car . "scm2cpp::car")
    (cdr . "scm2cpp::cdr")
    (append . "scm2cpp::append")
    (list-ref . "scm2cpp::list_ref")
    (list-tail . "scm2cpp::list_tail")
    ;; An unqualified abs resolves to the integer version from <cstdlib>.
    (abs . "std::abs")
    ;(set-car! . "scm2cpp::set_car")
))

(define (cpp-function-name-correspond-alist? f)
  (assoc f cpp-function-name-correspond-alist))


(define (cpp-function-name-in-correspond-alist f)
  (cdr (assoc f cpp-function-name-correspond-alist)))

;(cdr (assoc 'eq? cpp-function-name-correspond-alist))
;(assoc 'bbb cpp-function-name-correspond-alist)


;; (c-includes-add "aaa")
;; (c-includes-add "bbb")
;;  c-includes



(define (sexp-free-var expr )  
  (let-values ([(expr1 alpha1 free1)  (alpha-conv expr)])
    (let* (
	   (free1inv ( envinvert free1))
	   (freevars (map car free1inv))
	   )
      freevars)))

(define  (sexp-free-var? expr ) 
  (> (length (sexp-free-var expr )) 0))

;; (sexp-free-var '(let ((x 1) (y 3)) (+ x y)))  ;-> ()
;; (sexp-free-var '(let ((x 1) (y 3)) (+ x z)))  ;-> (z)
;; (sexp-free-var '(let ((x 1) (y 3)) (+ x z u w)))  ;-> (w u z)
;; (sexp-free-var? '(let ((x 1) (y 3)) (+ x z u w))) ;#t 
;; (sexp-free-var? '(let ((x 1) (y 3)) (+ x y))) ;#f


;; ;;
;; (cpptype 'int symbol->string) 
;; (cpptype '(lambda (int int ) double) symbol->string) 
;; (cpptype '(vector int int double) symbol->string) 
;; (cpptype '(list int int double) symbol->string) 
;; (cpptype '(list int int int) symbol->string) 


;; (define(var-env->ctype v env-type)
;;   (if (var-non-fix-type? v env-type)
;;       (var-name-to-template-type-name (cname (vtype v)))
;; 	(type->ctype (vtype v))
;; 	))
;; (define (type->cpptype t)
  

  
  


;;;; Rewrite a tail-recursive named let into a do loop before code generation.
;;;; Such a let otherwise becomes a closure structure; as a plain for loop the
;;;; output is readable and later passes such as OpenMP can be applied to it.

(define (sexp-occurs? name expr)
  (cond [(eq? name expr) #t]
	[(pair? expr) (or (sexp-occurs? name (car expr))
			  (sexp-occurs? name (cdr expr)))]
	[else #f]))

;; Is this of the form (NAME arg ...)?
(define (self-call? name expr n-args)
  (and (pair? expr) (eq? (car expr) name) (list? expr)
       (= (length (cdr expr)) n-args)))

(define (named-let->do name vars inits body)
  (define n (length vars))
  (define (bindings steps) (map (lambda (v i s) (list v i s)) vars inits steps))
  (define (clean? . exprs) (not (ormap (lambda (e) (sexp-occurs? name e)) exprs)))
  (match body
    ;; A value-returning named let may appear in expression position, whereas
    ;; do is only handled in statement position; leave those to the closure path.
    ;; Argument-less loop: (let NAME () (if TEST (begin STMT ... (NAME))))
    [(list (list 'if test (list 'begin stmts ... (? (lambda (c) (self-call? name c 0)) _))))
     (and (= n 0) (apply clean? test stmts)
	  `(do () ((not ,test) 0) ,@stmts))]
    ;; (let NAME () (when TEST STMT ... (NAME)))
    [(list (list 'when test stmts ... (? (lambda (c) (self-call? name c 0)) _)))
     (and (= n 0) (apply clean? test stmts)
	  `(do () ((not ,test) 0) ,@stmts))]
    ;; (let NAME () (cond (TEST STMT ... (NAME))))
    [(list (list 'cond (list test stmts ... (? (lambda (c) (self-call? name c 0)) _))))
     (and (= n 0) (apply clean? test stmts)
	  `(do () ((not ,test) 0) ,@stmts))]
    [_ #f]))

;; (letrec ((F (lambda (p ...) BODY))) (F arg ...)) is equivalent to a named
;; let, which is already generated as a self-referencing closure structure.
(define (letrec->named-let expr)
  (match expr
    [(list 'letrec (list (list f (list 'lambda (list ps ...) fbody ...)))
	   (list g args ...))
     (and (symbol? f) (eq? f g) (= (length ps) (length args))
	  `(let ,f ,(map list ps args) ,@fbody))]
    [_ #f]))

(define (rewrite-named-let expr)
  (match expr
    [(list 'quote _ ...) expr]
    [(list 'letrec _ ...)
     (let ([rewritten (letrec->named-let (map rewrite-named-let expr))])
       (or (and rewritten (rewrite-named-let rewritten))
	   (map rewrite-named-let expr)))]
    [(list 'let (? symbol? name) (list (list vars inits) ...) body ...)
     (let* ([inits* (map rewrite-named-let inits)]
	    [body*  (map rewrite-named-let body)])
       (or (named-let->do name vars inits* body*)
	   `(let ,name ,(map list vars inits*) ,@body*)))]
    [(? list?) (map rewrite-named-let expr)]
    [_ expr]))

;;;; ---------------- write-free analysis ----------------
;;;;
;;;; "Write-free" is deliberately not called const. C's const is a promise
;;;; over a binding's whole lifetime, declared up front and enforced by the
;;;; compiler; write-freedom is a fact about one region of the program,
;;;; discovered afterwards by analysis. The same array is typically written
;;;; while it is filled and write-free from then on, a phase change const
;;;; cannot express. Where a whole parameter really is write-free for the
;;;; whole call, that does coincide with const, and the code generator then
;;;; emits the C++ keyword; the region-local notion is the more general one.
;;;;
;;;; mutation-summary maps each top-level function name to the 0-based
;;;; indices of the parameters it may write to -- directly through set!,
;;;; vector-set! and the like, or by passing the parameter on to a call
;;;; that writes it. Computed as a fixpoint from the empty map, which
;;;; terminates because the sets only grow.

(define mutation-summary (make-hasheq))

;; Heads that never write to their arguments. Anything absent from this
;; list and without a summary is assumed to write every argument, so an
;; omission here only makes the analysis more conservative, never wrong.
(define non-mutating-heads
  '(let let* letrec letrec* lambda define if cond when unless begin do else
    quote and or not delay force make-promise
    vector-ref list-ref vector-length length car cdr cons list make-list
    make-vector display newline string-append number->string
    + - * / remainder quotient modulo max min abs expt
    sqrt sin cos tan exp log atan asin acos
    zero? even? odd? negative? positive? null? pair?
    < > <= >= = eq? eqv? equal?))

;; The members of PARAMS that EXPR may write to.
(define (expr-mutated-params expr params)
  (match expr
    [`(quote ,_) '()]
    [`(set! ,x ,e)
     (append (if (memq x params) (list x) '())
	     (expr-mutated-params e params))]
    [`(,(? (lambda (h) (memq h '(vector-set! set-car! set-cdr!))) _) ,x ,es ...)
     (append (if (memq x params) (list x) '())
	     (append-map (lambda (e) (expr-mutated-params e params)) es))]
    [`(,(? symbol? f) ,args ...)
     (append
      (cond
       [(hash-ref mutation-summary f #f)
	=> (lambda (idxs)
	     (filter-map (lambda (i)
			   (and (< i (length args))
				(let ([a (list-ref args i)])
				  (and (symbol? a) (memq a params) a))))
			 idxs))]
       [(memq f non-mutating-heads) '()]
       ;; Unknown callee -- a closure held in a variable, say: assume it
       ;; writes every parameter it is handed.
       [else (filter (lambda (a) (and (symbol? a) (memq a params))) args)])
      (append-map (lambda (e) (expr-mutated-params e params)) args))]
    [(? list?) (append-map (lambda (e) (expr-mutated-params e params)) expr)]
    [_ '()]))

(define (compute-mutation-summaries! prog)
  (hash-clear! mutation-summary)
  (let ([defs (filter (lambda (f) (match f [`(define (,_ ,_ ...) ,_ ...) #t] [_ #f]))
		      (match prog [`(begin ,forms ...) forms] [_ (list prog)]))])
    (for ([d defs])
      (match d [`(define (,f ,_ ...) ,_ ...) (hash-set! mutation-summary f '())]))
    (let fix ()
      (let ([changed #f])
	(for ([d defs])
	  (match d
	    [`(define (,f ,ps ...) ,body ...)
	     (let* ([m (remove-duplicates
			(append-map (lambda (e) (expr-mutated-params e ps)) body))]
		    [idxs (sort (filter-map (lambda (x) (index-of ps x)) m) <)])
	       (unless (equal? idxs (hash-ref mutation-summary f))
		 (set! changed #t)
		 (hash-set! mutation-summary f idxs)))]))
	(when changed (fix))))))

;; Does STMT possibly write V? The per-name direction of the same walk,
;; used to establish that V is write-free across a span of statements.
(define (stmt-writes? stmt v)
  (match stmt
    [`(quote ,_) #f]
    [`(set! ,x ,e) (or (eq? x v) (stmt-writes? e v))]
    [`(,(? (lambda (h) (memq h '(vector-set! set-car! set-cdr!))) _) ,x ,es ...)
     (or (eq? x v) (ormap (lambda (e) (stmt-writes? e v)) es))]
    [`(,(? symbol? f) ,args ...)
     (or (cond
	  [(hash-ref mutation-summary f #f)
	   => (lambda (idxs)
		(ormap (lambda (i) (and (< i (length args)) (eq? (list-ref args i) v)))
		       idxs))]
	  [(memq f non-mutating-heads) #f]
	  [else (and (memq v args) #t)])
	 (ormap (lambda (e) (stmt-writes? e v)) args))]
    [(? list?) (ormap (lambda (e) (stmt-writes? e v)) stmt)]
    [_ #f]))

(define (scm2cpp-match-port expr-org
			    port-h port-c
			    )
  (define str-a string-append)
  (define str-j string-join)
  (define port-o port-c)
  (define (pout str) (display str port-o))
  (define (hout str) (display str port-h))
  (define (cout str) (display str port-c))
  (define (hout-semi str) (fprintf port-h "~a;~n" str))
  (define pre-cexp  (list->stack (list "")))
  (define post-cexp (list->stack (list "")))
  (define (add-pre-cexp  str [lv 0])  (stack-set-apply! pre-cexp  lv (lambda (x) (str-a x str)))) ;; (set! pre-cexp (str-a pre-cexp str)))
  (define (add-pre-cexp-semi str [lv 0])  (add-pre-cexp  (format "~a;~n" str) lv))
  (define (add-post-cexp str [lv 0])  (stack-set-apply! post-cexp lv (lambda (x) (str-a x str))))
  (define (add-post-cexp-semi str [lv 0]) (add-post-cexp (format "~a;~n" str) lv))
  (define scope-level 0)
  (define (inc-lv [str0 ""] [str1 ""])
    (set! scope-level (+ scope-level 1))
    (stack-push! str0 pre-cexp )
    (stack-push! str1 post-cexp))
  (define (dec-lv)
    (set! scope-level (+ scope-level 1))
    (values
     (stack-pop! post-cexp)
     (stack-pop! pre-cexp)))
  (define-macro (begin-inc-lv . body)
   `(begin 
      (inc-lv)
      ,@body))
  (define-macro (begin-dec-lv . body)
   (let ((begin-dev-lv-last-ret (gensym)))
     `(let ((,begin-dev-lv-last-ret (begin ,@body)))
	(dec-lv)
	,begin-dev-lv-last-ret
	)))
  (define-macro (begin-inc-dev-lv . body)
   (let ((begin-inc-dev-lv-last-ret (gensym)))
     `(let ((,begin-inc-dev-lv-last-ret (begin-inc-lv ,@body)))
	(dec-lv)
	,begin-inc-dev-lv-last-ret
	)))
  ;;;; Parallel back ends, selected through SCM2CPP_PARALLEL.
  ;;;;
  ;;;; Because a named let and a do loop are emitted as an ordinary for loop
  ;;;; rather than as a closure, a directive placed in front of it is enough to
  ;;;; hand the loop to OpenMP, to an offload target or to OpenACC. Only the
  ;;;; outermost loop is annotated; in-parallel-loop records whether generation
  ;;;; is already inside an annotated one.
  (define in-parallel-loop #f)
  (define (parallel-pragma)
    (if in-parallel-loop "" (parallel-pragma-1)))
  (define (parallel-pragma-1)
    (let ([m (getenv "SCM2CPP_PARALLEL")])
      (cond
       [(not m) ""]
       [(string=? m "omp") (format "~n#pragma omp parallel for~n")]
       [(string=? m "gpu") (format "~n#pragma omp target teams distribute parallel for~n")]
       [(string=? m "acc") (format "~n#pragma acc parallel loop~n")]
       [else ""])))
  ;;;; The Thrust back end does not annotate the loop but replaces it. Two
  ;;;; shapes are recognised, both written as an accumulator over a vector:
  ;;;; a running sum written back elementwise is a scan, and one that is not
  ;;;; written back is a reduction.
  (define (thrust-mode?) (equal? (getenv "SCM2CPP_PARALLEL") "thrust"))
  ;;;; The integral-image rewrite, selected through SCM2CPP_INTEG.
  ;;;;
  ;;;; The value is either "auto", applying the rewrite wherever a box-sum
  ;;;; nest of any rank is recognised, or a space-separated list of NAME or
  ;;;; NAME:RANK tokens naming the arrays it may be applied to. NAME alone
  ;;;; matches at whichever rank the nest is actually found; NAME:RANK
  ;;;; additionally asserts what that rank ought to be, and is rejected if
  ;;;; the nest found does not match it. The names are hints: they may be
  ;;;; written by hand, or proposed by a language model (--llm-hints), and a
  ;;;; hint on an array whose loop nest does not match the shape is simply
  ;;;; never used. The rewrite is valid when every write to the array
  ;;;; precedes the nest, which the recogniser cannot see; that is what the
  ;;;; hint asserts.
  (define (integ-hints)
    (let ([m (getenv "SCM2CPP_INTEG")])
      (cond [(not m) '()]
	    [(string=? m "auto") 'auto]
	    [else (map (lambda (tok)
			 (let ([parts (string-split tok ":")])
			   (cons (string->symbol (car parts))
				 (and (pair? (cdr parts)) (string->number (cadr parts))))))
		       (string-split m))])))
  ;; The hint names arrays as they appear in the source, but by the time
  ;; the nest is matched alpha conversion may have renamed the symbol (a
  ;; local x alongside some function's parameter x, say), so compare on the
  ;; original name that orgn recovers.
  (define (integ-hinted? v rank)
    (let ([h (integ-hints)])
      (cond [(eq? h 'auto) #t]
	    [(list? h) (let ([e (or (assq v h) (assq (orgn v) h))])
			 (and e (or (not (cdr e)) (= (cdr e) rank))))]
	    [else #f])))
  ;; The element type for the template argument, taken from the literal that
  ;; initialises the accumulator: an exact zero accumulates ints, an inexact
  ;; one doubles.
  (define (integ-elem-type z)
    (if (and (real? z) (inexact? z)) "double" "int"))
  ;; The rank-n box-sum-from-origin nest, generalising
  ;;   (do ((i 0 (+ i 1))) ((= i n))
  ;;     (do ((j 0 (+ j 1))) ((= j n))
  ;;       (let ((acc 0))
  ;;         (do ((a 0 (+ a 1))) ((= a (+ i 1)))
  ;;           (do ((b 0 (+ b 1))) ((= b (+ j 1)))
  ;;             (set! acc (+ acc (vector-ref v (+ (* a n) b))))))
  ;;         (vector-set! s (+ (* i n) j) acc))))
  ;; to n output loops (i, j, ...) and n matching accumulation loops (a, b,
  ;; ...), one pair per axis, each accumulation loop k bounded by (+ Ik 1)
  ;; where Ik is the output loop at the same position. n is discovered from
  ;; the nest itself, not told to the recogniser: peeling stops as soon as
  ;; the (let ((acc 0)) ...) at the centre is found. The two axes need not
  ;; share a size; only that v and s are indexed by the same row-major
  ;; flattening of the same n indices with the same per-axis sizes.
  ;;
  ;; Peel one output loop layer; returns (values I N body) or (values #f #f #f).
  (define (integ-peel-output expr)
    (match expr
      [`(do ((,I 0 (+ ,I2 1))) ((= ,I3 ,N)) ,B)
       #:when (and (eq? I I2) (eq? I I3))
       (values I N B)]
      [_ (values #f #f #f)]))
  ;; Peel one accumulation loop bounded by (+ IK 1); returns (values A body) or (values #f #f).
  (define (integ-peel-accum expr IK)
    (match expr
      [`(do ((,A 0 (+ ,A2 1))) ((= ,A3 (+ ,IK2 1))) ,B)
       #:when (and (eq? A A2) (eq? A A3) (eq? IK2 IK))
       (values A B)]
      [_ (values #f #f)]))
  ;; Peel one accumulation loop per entry of Is, in the same order; returns
  ;; (values (list A ...) final-form) or (values #f #f).
  (define (integ-peel-accums body Is)
    (if (null? Is)
	(values '() body)
	(let-values ([(A rest) (integ-peel-accum body (car Is))])
	  (if (not A) (values #f #f)
	      (let-values ([(As final) (integ-peel-accums rest (cdr Is))])
		(if (not As) (values #f #f) (values (cons A As) final)))))))
  ;; Peel output loops until the (let ((acc 0)) accum-nest vector-set!) at
  ;; the centre is found; returns (values Is Ns acc-var zero-lit accum-nest
  ;; vector-set!-form) or six #f if the nest never bottoms out that way.
  (define (integ-discover expr)
    (let loop ([e expr] [Is '()] [Ns '()])
      (match e
	[`(let ((,ACC ,(? number? Z))) ,ACCNEST ,VSET)
	 #:when (and (zero? Z) (pair? Is))
	 (values (reverse Is) (reverse Ns) ACC Z ACCNEST VSET)]
	[_
	 (let-values ([(I N body) (integ-peel-output e)])
	   (if (not I) (values #f #f #f #f #f #f)
	       (loop body (cons I Is) (cons N Ns))))])))
  ;; Row-major flattening of VARS over per-axis sizes DIMS, as an s-expression
  ;; matched against the source's own index expression: (v1*d2+v2)*d3+v3 ...
  (define (integ-flatten vars dims)
    (let loop ([acc (car vars)] [vs (cdr vars)] [ds (cdr dims)])
      (if (null? vs) acc
	  (loop `(+ (* ,acc ,(car ds)) ,(car vs)) (cdr vs) (cdr ds)))))
  ;; The same flattening, rendered as C++ text over already-formatted operands.
  (define (integ-cexp-flatten vars dims)
    (let loop ([acc (car vars)] [vs (cdr vars)] [ds (cdr dims)])
      (if (null? vs) acc
	  (loop (format "(~a*~a+~a)" acc (car ds) (car vs)) (cdr vs) (cdr ds)))))
  ;; Pure shape test: (values V S Is Ns Z) when EXPR is the box-sum nest,
  ;; five #f otherwise. No hint check and no include emission, so the share
  ;; planner below can probe statements without side effects.
  (define (integ-match-nest expr)
    (let-values ([(Is Ns ACC Z ACCNEST VSET) (integ-discover expr)])
      (if (not Is)
	  (values #f #f #f #f #f)
	  (let-values ([(As final) (integ-peel-accums ACCNEST Is)])
	    (if (not As)
		(values #f #f #f #f #f)
		(match (list final VSET)
		  [(list `(set! ,ACC2 (+ ,ACC3 (vector-ref ,V ,IDX)))
			 `(vector-set! ,S ,OIDX ,ACC4))
		   #:when (and (eq? ACC2 ACC) (eq? ACC3 ACC) (eq? ACC4 ACC)
			       (symbol? V) (symbol? S)
			       ;; With the same array as source and
			       ;; destination the nest reads cells it has
			       ;; already overwritten; a snapshot changes
			       ;; the meaning, so no rewrite.
			       (not (eq? V S))
			       (equal? IDX (integ-flatten As Ns))
			       (equal? OIDX (integ-flatten Is Ns)))
		   (values V S Is Ns Z)]
		  [_ (values #f #f #f #f #f)]))))))
  ;;;; Sharing one table among sibling nests. When several statements of one
  ;;;; sequence are box-sum nests over the same array with the same extents,
  ;;;; and the span from the first to the last is write-free for that array,
  ;;;; a single snapshot serves them all: the first nest declares and builds
  ;;;; the table, without braces so it lives to the end of the enclosing
  ;;;; scope, and the later nests only query it. integ-share-plan holds the
  ;;;; decision while the sequence is being emitted; entries are pushed on
  ;;;; entry to the sequence and popped on the way out, so nested sequences
  ;;;; shadow naturally, as do the identically named C++ declarations.
  (define integ-share-plan '())  ; alist V -> (vector table-name rank built?)
  (define (integ-plan-sequence Es)
    (let* ([nests (filter values
			  (for/list ([e Es] [i (in-naturals)])
			    (let-values ([(V S Is Ns Z) (integ-match-nest e)])
			      (and V (list i (list V (length Is) Ns))))))]
	   [keys (remove-duplicates (map cadr nests))]
	   [cands
	    (filter-map
	     (lambda (key)
	       (let* ([v (car key)] [rank (cadr key)]
		      [idxs (filter-map (lambda (n) (and (equal? (cadr n) key) (car n)))
					nests)])
		 (and (>= (length idxs) 2)
		      (integ-hinted? v rank)
		      (let ([lo (apply min idxs)] [hi (apply max idxs)])
			(for/and ([e Es] [i (in-naturals)])
			  (or (< i lo) (> i hi) (memq i idxs)
			      (not (stmt-writes? e v)))))
		      (cons v (vector (format "scm2cpp_ii_~a" (cname v)) rank #f)))))
	     keys)])
      ;; The same array wanted at two different extents cannot share one
      ;; name; leave such an array to the per-nest path entirely.
      (filter (lambda (c)
		(= 1 (length (filter (lambda (d) (eq? (car d) (car c))) cands))))
	      cands)))
  (define (integ-emit V S Is Ns Z)
    (let* ([n (length Is)]
	   [cis (map cname Is)] [cns (map cexp Ns)]
	   [cv (cname V)] [cs (cname S)] [et (integ-elem-type Z)]
	   [zeros (map (lambda (_) "0") cis)]
	   [loops (string-join
		   (map (lambda (ci cn) (format "for (int ~a = 0; ~a < ~a; ~a++)" ci ci cn ci))
			cis cns)
		   "\n")]
	   [share (assq V integ-share-plan)]
	   [tname (if share (vector-ref (cdr share) 0) "scm2cpp_ii")]
	   [queries (format (string-append
			     "~a {~n"
			     "const int scm2cpp_lo[~a] = { ~a };~n"
			     "const int scm2cpp_hi[~a] = { ~a };~n"
			     "~a[ ~a ] = ~a.query(scm2cpp_lo, scm2cpp_hi);~n"
			     "}")
			    loops
			    n (string-join zeros ", ") n (string-join cis ", ")
			    cs (integ-cexp-flatten cis cns) tname)]
	   [build (format (string-append
			   "scm2cpp::integral_image<~a,~a> ~a;~n"
			   "{ const int scm2cpp_dims[~a] = { ~a };~n"
			   "~a.build(~a, scm2cpp_dims); }~n")
			  et n tname n (string-join cns ", ") tname cv)])
      (cond
       [(and share (vector-ref (cdr share) 2))
	;; already built earlier in this write-free span; query only
	queries]
       [share
	(vector-set! (cdr share) 2 #t)
	(str-a build queries)]
       [else (str-a "{ " build queries " }")])))
  (define (integ-boxsum-nest expr)
    (let-values ([(V S Is Ns Z) (integ-match-nest expr)])
      (and V (integ-hinted? V (length Is))
	   (begin
	     (c-includes-adds (list "<vector>" "\"scm2cpp.hpp\""))
	     (integ-emit V S Is Ns Z)))))
  ;; (do ((i 0 (+ i 1))) ((= i N) _) (set! acc (+ acc (vector-ref v i)))
  ;;                                 (vector-set! sv i acc))
  (define (thrust-scan bindings pred E)
    (match (list bindings pred E)
      [(list (list (list i 0 `(+ ,i2 1)))
	     (list `(= ,i3 ,_) _ ...)
	     (list `(set! ,acc (+ ,acc2 (vector-ref ,v ,i4)))
		   `(vector-set! ,sv ,i5 ,acc3)))
       (and (eq? i i2) (eq? i i3) (eq? i i4) (eq? i i5)
	    (eq? acc acc2) (eq? acc acc3)
	    (cons v sv))]
      [_ #f]))
  ;; (do ((i 0 (+ i 1))) ((= i N) _) (set! acc (+ acc (vector-ref v i))))
  (define (thrust-reduce bindings pred E)
    (match (list bindings pred E)
      [(list (list (list i 0 `(+ ,i2 1)))
	     (list `(= ,i3 ,_) _ ...)
	     (list `(set! ,acc (+ ,acc2 (vector-ref ,v ,i4)))))
       (and (eq? i i2) (eq? i i3) (eq? i i4) (eq? acc acc2)
	    (cons v acc))]
      [_ #f]))
  ;; Returns the replacement expression, or #f to fall through to a for loop.
  (define (thrust-loop bindings pred E)
    (and (thrust-mode?)
	 (let ([sc (thrust-scan bindings pred E)])
	   (if sc
	       (begin
		 (c-includes-adds (list "<thrust/scan.h>" "<thrust/device_vector.h>"))
		 (format "thrust::inclusive_scan(~a.begin(),~a.end(),~a.begin())"
			 (cname (car sc)) (cname (car sc)) (cname (cdr sc))))
	       (let ([rd (thrust-reduce bindings pred E)])
		 (and rd
		      (begin
			(c-includes-adds (list "<thrust/reduce.h>" "<thrust/device_vector.h>"))
			(format "~a = thrust::reduce(~a.begin(),~a.end(),~a)"
				(cname (cdr rd)) (cname (car rd)) (cname (car rd))
				(cname (cdr rd))))))))))
  (define pre-cfun "")
  (define post-cfun "")
  (define (add-pre-cfun str) (set! pre-cfun (str-a pre-cfun str)))
  (define (add-pre-cfun-semi str) (add-pre-cfun (format "~a;~n" str))) 
  (define current-template-vars '())  
  (define current-template-types '())  
  (define c-includes '())
  ;; Forward declarations, emitted together at the head of the header so that
  ;; a function may call one defined later.
  (define c-fwd-decls '())
  (define (c-fwd-decl-add str)
    (set! c-fwd-decls (append c-fwd-decls (list str))))
  (define (c-includes-add str)
    (set! c-includes (lset-union equal? c-includes (list str))))
  (define (c-includes-adds lst)
    (set! c-includes (lset-union equal? c-includes lst)))
  ;; (define-values (expr-alpha env-alpha env-free)  
  ;;   (alpha-conv (list 'begin expr-org)))
  ;; (define env-alpha-inv (envinvert env-alpha))
  ;; (define env-free-inv ( envinvert env-free))
  ;; (define env-init-type (alpha-free->type-env env-alpha-inv env-free-inv))
  ;; (define env-ret-type (%which (Env Ret) (%derive-type expr-alpha Ret env-init-type Env )))
  ;; (define env-type
  ;;   (if env-ret-type
  ;; 	(reduce-unknown-type (cdr (assq 'Env env-ret-type)))
  ;; 	#f))
  (define-values (env-type-global gloal-ret-type unknown-type-list expr-alpha env-alpha-inv env-free-inv)   (infer-type-from-org-expr expr-org ))
  (define env-type-local env-type-global)

  (define top-level-global-vars (expr-type->global-vars expr-alpha env-type-global))
  ;(define top-level-functions-undef-types-alist      (functions-undef-types-alist expr-alpha env-type-global unknown-type-list top-level-global-vars))
  (define function-free-type-variable-bind-free-alist (functions-undef-types-alist expr-alpha env-type-global unknown-type-list top-level-global-vars))
  (define free-type-variables (flatten (map (lambda (kv) (append (cadr kv) (caddr kv)))    function-free-type-variable-bind-free-alist)))
  (display (list 'free-type-variables free-type-variables))(newline)

  ;; (define free-type-variables-template-name-alist (map (lambda (v) (display v)(cons v (var-name-to-template-type-name (cname v)))) free-type-variables))
  ;; (display (list 'free-type-variables-template-name-alist free-type-variables-template-name-alist))(newline)


  ;(display (list env-type-global gloal-ret-type unknown-type-list expr-alpha env-alpha-inv env-free-inv))(newline)

  (define (orgn v) (env2-rename v env-alpha-inv env-free-inv))
  (define (cname v) (schlep-symbol-str (orgn v)))
  ;(define (vtype v) (var-env->type v env-type-local))
  (define (vtype v) (var-env->direct-type v env-type-local))



  (define (non-fix-type? v)  (var-non-fix-type? v env-type-local))
  (define (expr->type expr-local)
    (cond 
     [(symbol? expr-local) (vtype expr-local)]
     [else (quick-derive-return-type expr-local env-type-local)
      ;; (let*-values
      ;; 	  (
      ;; 	   ;; [(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
      ;; 	   [(type1 ret1 unk1) (derive-type expr-local env-type-local)])
      ;;   ;(display (list "expr->type1" expr-local ret1))
      ;; 	ret1
      ;; 	)
      ]))
  ;; (define (expr->expand-type expr-local)  
  ;;   (cond
  ;;    [(symbol? expr-local)       
  ;;   ;(expand-type 
  ;;    (expr->type expr-local) env-type-local)
  ;; )
  
  ;; Template parameter names are derived from the variable name, so two
  ;; distinct type variables from different scopes could collide and be
  ;; conflated. Assign per type variable and disambiguate on collision.
  (define tvar-name-table (make-hasheq))
  (define tvar-name-used (make-hash))
  (define (tvar-name v)
    (hash-ref!
     tvar-name-table v
     (lambda ()
       (let ([base (var-name-to-template-type-name (cname v))])
	 (let loop ([n 1])
	   (let ([cand (if (= n 1) base (format "~a~a" base n))])
	     (if (hash-ref tvar-name-used cand #f)
		 (loop (+ n 1))
		 (begin (hash-set! tvar-name-used cand #t) cand))))))))
  (define (ctype v)
    (if (non-fix-type? v)
	(tvar-name (vtype v))
	(type->ctype (vtype v))
	))
  ;; number-type-order-list runs from narrow to wide; take the widest.
  (define (widest-number-type ts)
    (let loop ([rest number-type-order-list] [found #f])
      (cond [(null? rest) found]
	    [(memq (car rest) ts) (loop (cdr rest) (car rest))]
	    [else (loop (cdr rest) found)])))
  (define (type-variable? m) (and (symbol? m) (not (memq m type-symbols))))
  (define (numeric-collapsible-union? E)
    (and (pair? (filter number-type? E))
	 (andmap (lambda (m) (or (number-type? m) (type-variable? m))) E)))
  (define (cppuniontype E)
    ;; A union that includes a path yielding no value is used in statement
    ;; position; emit void.
    (if (memq Void E)
	(type->ctype Void)
    ;; A union of numeric types and type variables collapses to the widest
    ;; numeric type, which is what C++ arithmetic conversion does anyway.
    (if (numeric-collapsible-union? E)
	(cpptype (widest-number-type (filter number-type? E)))
	(begin
	  (c-includes-add "\"scm2cpp.hpp\"" )
	  (format
	   "typename scm2cpp::make_variant_shrink_over< boost::mpl::vector< ~a > >::type "
	   (string-join (map cpptype E) ","))))))
  (define (cpptype-arg t)
    (cond 
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [else (cpptype t) ]))
  (define (cpptype t);;type->cpptype
    ;(display (list "cpptype0 " t))(newline)
    (cond
     ;[(symbol? t) (ctype t)]
     [(member t unknown-type-list) (tvar-name t)]
     [(optional-union-type? t) => (lambda (x) (format "boost::optional<~a>" (cpptype x)  ))]
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [(symbol? t)  (type->ctype t)]
      
     ;[(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (tvar-name v))  ]
     [else
      (match 
       t
     ;[(? symbol? X)  (ctype X)]
       [`(,(? union-symbol? U) ,E ...) 
	;(if  (pair? (lset-intersection eq? E unknown-type-list))
	(let* ([var-types (lset-intersection eq? E unknown-type-list)]
	       ;; vtype returns a symbol when the type is unresolved, but
	       ;; lset-union requires lists.
	       [var-type-lists (map (lambda (v) (let ([t (vtype v)]) (if (list? t) t (list t)))) var-types)]
	       [E-subtrected
	       (lset-difference equal? E
				(apply lset-union (cons eq? var-type-lists)))])
	  (if (pair? (lset-intersection eq? E-subtrected number-type-order-list))
	      (let  ([ts (lset-difference eq? E-subtrected (list Number))])
		(if ( = 1 (length ts))
		    (cpptype (car ts))		  
		    (cppuniontype ts)))
	      ;(cppuniontype E)
	      (cppuniontype (lset-difference eq?  E (list Number)) )
	      )
	  ;; (cppuniontype e))
	  )
       	]

     [`(lambda ,params ,ret)
      (c-includes-adds (list "<boost/function.hpp>" "<functional>" "<algorithm>"))
      (format "boost::function< ~a ( ~a ) >" (ctype ret) (string-join (map cpptype params) ","))
      ]
     [`(make-vector ,(? number? N) ,V) 
      (c-includes-add "<boost/array.hpp>" )
      (format "boost::array<~a,~a>" (cpptype V) N  )]
     [`(make-vector ,N ,V) 
      (c-includes-add "<vector>" )
      (format "std::vector<~a>" (cpptype V)  )]
     [`(make-list ,(? number? N) ,V) 
      (c-includes-add "<boost/array.hpp>" )
      (format "boost::array<~a,~a>" (cpptype V) N  )]
     [`(make-list ,N ,V) 
      (c-includes-add "<vector>" )
      (format "std::vector<~a>" (cpptype V)  )]
     [`(vector ,params ... )
      (let ((tps (map cpptype params))) 
	(if (list-all-equal? tps)
	    (begin 
	      (c-includes-add "<boost/array.hpp>")
	      (format "boost::array<~a,~a>" (cpptype (car tps)) (length params))
	      )
	  (begin
	    (c-includes-add "<boost/fusion/include/vector.hpp>")
	    (format "boost::fusion::vector<~a>" (string-join tps ",")))))
      ]
     ;; The nominal recursive type; scm2cpp::stream_cell<T> in the runtime.
     [`(scm2cpp-stream ,T)
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::stream_cell< ~a >" (cpptype T))]
     ;; The summed-area representation, for an array whose reads are box sums.
     [`(integral-image ,T ,(? number? R))
      (c-includes-adds (list "<vector>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::integral_image< ~a,~a >" (cpptype T) R)]
     [`(list ,params ... )
      (if (list-all-equal? params)
	  (begin
	    (c-includes-add "<list>")
	    (format "std::list< ~a >" (cpptype (car params))))
	  (begin 
	    (c-includes-add "<boost/fusion/include/list.hpp>")
	    (format "boost::fusion::list< ~a >" (string-join (map cpptype params) ","))))
      ]
     ;; An unrecognised compound type whose head is an unknown type is treated
     ;; as a template parameter. Unknown types made on another path are not in
     ;; unknown-type-list, so match on the name.
     [(list (? (lambda (x)
		 (and (symbol? x)
		      (or (memq x unknown-type-list)
			  (regexp-match? #px"^Unknown-Type" (symbol->string x))))) U) _ ...)
      (tvar-name U)]
     [_ 
      ;; (let*-values
      ;; 	  (
      ;; 	   ;; [(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
      ;; 	   [(type1 ret1 unk1) (derive-type t env-type-local)])
	(ctype t ) ]
     ) ]))
  (define (sarg->cpptype e) 
    (let ([t (expr->type e)])
    ;(cpptype-arg (expr->type e))
      (display (list 'sarg->cpptype e t))(newline)
      (if (pair? t)
	(cond
	 [(member e t) (tvar-name e) ]
	 [else	(sexp->cpptype e t)]
	 )
	(sexp->cpptype e t))
    ))

  (define (sexp->cpptype e [t-ret NoType])
    ;(display (list 'sexp->cpptype e))(newline)
    (let ([t (if (eq? t-ret NoType)
		 (expr->type e) t-ret)])
      (display (list 'sexp->cpptype e t))(newline)
      (cond
       [(assoc t ctype-alist) => cdr]
       [(eq? t e) (cpptype-arg t)]
       ;; t is not necessarily a list; member requires one.
       [(and (list? t) (member e t)) (cpptype-arg t)]
       [else (cpptype t)];;(expand-type (expr->type e) env-type-local)
       )))
  ;; Scheme vectors, lists and the like are shared mutable objects: a
  ;; function that calls vector-set! on a parameter is expected, by Scheme's
  ;; own semantics, to mutate the very vector the caller passed in. Passing
  ;; such a parameter by C++ value instead copies it, so the mutation is
  ;; invisible to the caller -- silently, since the code still compiles and
  ;; runs, just computing nothing the caller can see. Container-typed
  ;; parameters are therefore always passed by reference, independently of
  ;; ref-flag, which still governs the unrelated case of a closure's
  ;; captured free variables.
  ;; Only the types actually written to via vector-set!/set-car!-style
  ;; mutation need reference passing. Streams and integral images are read
  ;; through car/cdr/query rather than mutated in place once built, are
  ;; sometimes passed as the temporary result of another call (stream_cdr's
  ;; return value, for instance), and a non-const reference parameter cannot
  ;; bind to a temporary; forcing one here broke exactly that call.
  (define (container-type? t)
    (and (pair? t)
	 (memq (car t) '(make-vector make-list vector list))))
  ;; Same computation as sarg->cpptype, but also reports whether the type is
  ;; a container, both read off the one expr->type call. expr->type re-runs
  ;; relational inference against whatever constraint state is current, so a
  ;; second, separate call for the same variable is not guaranteed to see
  ;; the same type as the first -- it is not a pure lookup.
  (define (sarg->cpptype/ref e)
    (let ([t (expr->type e)])
      (values
       (if (pair? t)
	   (cond [(member e t) (tvar-name e)]
		 [else (sexp->cpptype e t)])
	   (sexp->cpptype e t))
       (container-type? t))))
  ;; MUTATED, when given, lists the parameters the function may write to,
  ;; from the mutation summary; a container parameter not among them is
  ;; write-free for the whole call, which is the one case where the
  ;; region-local notion coincides with C++ const, so the keyword is
  ;; emitted. A const reference also accepts a temporary argument, which a
  ;; plain reference does not.
  (define (svars->cargs vars ref-flag [mutated #f])
    ;(display (list "svars->cargs " vars ref-flag))(newline)
    (let*-values ([(ctypes refs)
		   (let loop ([vs vars] [cts '()] [rfs '()])
		     (if (null? vs)
			 (values (reverse cts) (reverse rfs))
			 (let-values ([(ct rf) (sarg->cpptype/ref (car vs))])
			   (loop (cdr vs) (cons ct cts) (cons rf rfs)))))]
		  [(cvars) (map cname vars)])
      (string-join
       (map (lambda (t v r orig)
	      (cond
	       [(and r mutated (not (memq orig mutated)))
		(format " const ~a & ~a " t v)]
	       [(or ref-flag r) (format " ~a & ~a " t v)]
	       [else (format " ~a  ~a " t v)]))
	    ctypes cvars refs vars)
       " , ")))
  (define (svars->crefs vars) (string-join (map cname vars) " , "))  
  (define (svars->cdefs vars ref-flag) ;return str : int a; float b; ...
    (let* ((cvars (map cname vars))
	   (ctypes (map sexp->cpptype vars))
	   (ctop (if ref-flag " & " "")))
      (apply string-append (map (lambda (t v) (format "~a ~a ~a;~n" t ctop v)) ctypes cvars))))
  (define (svars->cinit vars)
    (let* ((cvars (map cname vars)))
      (if (null? vars)
	  ""
	  (string-append ":" (string-join (map (lambda (v) (format "~a(~a) " v v )) cvars) ",")))))

  (define (svars->ctemplatedef vars)(types->ctemplatedef vars))
  (define (types->ctemplatedef vars)
    ;; A name appearing twice is not legal C++, so remove duplicates.
    (let ([names (delete-duplicates (map tvar-name vars))])
      (types->ctemplatedef-names names)))
  (define (types->ctemplatedef-names names)
    (if (null? names) ""
	(format "template< ~a > "
		(str-j (map (lambda (n) (format "typename ~a" n)) names) ","))))
  ;; A parameter that does not occur in the signature cannot be deduced, and
  ;; the function cannot be called at all. Keep only those that are used.
  ;; The occurrence test needs pregexp: regexp does not interpret \\b.
  (define (types->ctemplatedef-used vars signature-str)
    (let* ([names (delete-duplicates (map tvar-name vars))]
	   [used (filter (lambda (n) (regexp-match? (pregexp (string-append "\\b" (regexp-quote n) "\\b"))
						    signature-str))
			 names)])
      (types->ctemplatedef-names used)))
  (define (clambda expr lambda-name lambda-obj-name free-ref-flag)
    (let-values ([(type1 lambda-type1 unk1) (derive-type expr env-type-local)])
      (let* ((freevars (sexp-free-var expr )) 
	     (lambda-ret-type (last lambda-type1)) 
	     ( cdef-lambda-obj "")
	     ;; A struct whose name equals the object's clashes with the member,
	     ;; which is not legal C++. lambda-obj-name is #f for anonymous ones.
	     ( c-lambda-name (let* ([n (cname lambda-name)]
				    [o (and lambda-obj-name (cname lambda-obj-name))])
			       (if (and o (string=? n o)) (string-append n "_fn") n)))
	     ( c-local-defs (svars->cdefs freevars free-ref-flag))
	     ( c-local-init-args '())
	     ( c-init-args (svars->cargs freevars free-ref-flag))
	     )
	;(newline)(display (list 'clambda lambda-obj-name freevars  expr ))(newline)
      (when 
       lambda-obj-name 
       (begin
	 ;; (set! freevars (lset-difference equal?  freevars (list lambda-obj-name))) 
	 (set! cdef-lambda-obj (format "~a(~a)" (cname lambda-obj-name) (svars->crefs freevars)))
	 (set! c-local-init-args
	       (map (lambda (x) 
		      (format "~a & ~a"	
			      (if (equal? x lambda-obj-name) 
				  c-lambda-name
				  (sexp->cpptype x)) 
			      (cname x))) freevars))	      
	 (set! c-local-defs  (str-a  (str-j c-local-init-args (format ";~n")) (format ";~n")))
	 (set! c-init-args  (str-j c-local-init-args (format " , ")))
	 ))
	;(newline)(display (list 'clambda1 lambda-obj-name freevars  expr ))(newline)
      (match
       expr
       [`(lambda ,params ,E ... ) 
	;(display (list 'clambda expr E))(newline)
	(format "~n struct ~a { ~n ~a  ~a(~a)~a {} ~n ~a operator()(~a ) ~n { ~a } } ~a " 
		c-lambda-name
		;(svars->cdefs freevars free-ref-flag) 
		c-local-defs
		c-lambda-name c-init-args (svars->cinit freevars) 		
		;(sexp->cpptype lambda-ret-type)  
		(cpptype lambda-ret-type)  
		(svars->cargs params #false) 
		(begin-inc-dev-lv   
		 (cstat-ret (cons 'begin E))) cdef-lambda-obj )
	]
       ))))

  (define (cexp-with-local-analysis expr-local [t-ref NoType])
    (let*-values
	([(expr-alpha-loc env-alpha-loc env-free-loc) (alpha-conv expr-local)]
	 ;[(type1 ret1 unk1) (derive-type expr-local env-type-local)]
	 )
      (let* ((alpha1env  (envinvert env-alpha-loc)) 
	    (free1env (envinvert env-free-loc))
	    (vars1 (map car alpha1env))
	    (freevars1 (map car free1env)))
	;(display (list alpha1env type1))
	;(display (list "cexp-with-local-analysis " vars1 freevars1  expr-local))(newline)
	(match 
	 expr-local
	 [`(cond ,E ...)
	  (let ((lambda-name  (gensym 'cond) ))
	    (add-pre-cexp-semi
	     (clambda `(lambda () ,expr-local) lambda-name #false #true))
	    (str-a (cname lambda-name)
	 	   "(" (str-j (map cname freevars1) ",")")"
	 	   "()"))]
	 [`(let (,V ... ) ,E ...) 
	  (let ((lambda-name  (gensym 'let) ))
	    (add-pre-cexp-semi
	     (clambda
	      (cons 'lambda (cons (map car V) E))
	      lambda-name #false #true)
	     )
	    (str-a (cname lambda-name)
		   "(" (str-j (map cname freevars1) ",")")"
		   "(" (str-j (map cexp (map cadr V)) ",")")"))
	  ]
	 [`(let ((,L (lambda ,params ,E ... ))),L)
	  (let ((lambda-name L )
		(tvars (lset-intersection eq? current-template-vars  (append vars1 freevars1))) )
	    (if (null? current-template-vars)
		(hout-semi
		 (clambda expr-local lambda-name #false #false))
		(add-pre-cfun-semi
		 (str-a 
		  (svars->ctemplatedef tvars)
		  (clambda expr-local lambda-name #false #false))))
	    (str-a (cname lambda-name)
		   (if (null? tvars) "" (format "< ~a >" (str-j (map sexp->cpptype tvars) ",")))
		   "(" (str-j (map cname freevars1) ",")")"))]
	 [`(lambda ,params ,E ... ) 	  
	  (let ((lambda-name  (gensym 'lambda) )
		(tvars (lset-intersection eq? current-template-vars  (append vars1 freevars1))) )
	    (if (null? current-template-vars)
		(hout-semi
		 (clambda expr-local lambda-name #false #false))
		(add-pre-cfun-semi
		 (str-a 
		  (svars->ctemplatedef tvars)
		  (clambda expr-local lambda-name #false #false))))
	    (str-a (cname lambda-name)
		   (if (null? tvars) "" (format "< ~a >" (str-j (map sexp->cpptype tvars) ",")))
		   "(" (str-j (map cname freevars1) ",")")")
	    )
	  ]
	 [`(let ,(? symbol? v) (,V ...) ,E ... )  ;;named let
	  ;(display (list 'cexp-named-let v V E))(newline)
	  (set! env-alpha-inv (alist-cons-update v v env-alpha-inv))
	  (let ((lambda-name (gensym v ))
		(lambda-obj-name  v )
		;;(varnexts (map (lambda (e) `(set! ,(car e) ,(caddr e)   )) V))
		)
	    (add-pre-cexp-semi
	     (clambda
	      (cons 'lambda (cons (map car V) E))
	      lambda-name lambda-obj-name #true)
	     )
            ;(display (list 'cexp-named-let1 v V E lambda-obj-name freevars1 ))(newline)
	    (str-a 
	     (cname lambda-obj-name)	     
		   ;; "(" (str-j (map cname 
		   ;; 		   ;(lset-difference equal?  freevars1 (list lambda-obj-name)) 
                   ;;                ;(remove lambda-obj-name freevars1)
                   ;;                 freevars1
                   ;;                ) ",")")"
		   "(" (str-j (map cexp (map cadr V)) ",")")"))
	  ]
	 [`(,E0 ,Es ...) 
	  ;(display (list 'cexp-funcall E0 Es (null? Es) ))(newline)
	  (display (list 'cexp-funcall E0 Es  ))(newline)

	  (if (and (symbol? E0) (assoc E0 function-free-type-variable-bind-free-alist) 
		   (or (pair? (cadr (assoc E0 function-free-type-variable-bind-free-alist)))
		       (pair? (caddr (assoc E0 function-free-type-variable-bind-free-alist)))) )
	      (let ([E0-cstr (if (symbol? E0) (cname E0) (cexp E0))]
		    [E0-type (expr->type E0)]
	  	    [env-type-local-old env-type-local]
	  	    [unknown-type-list-old unknown-type-list])
	  	(match 
	  	 E0-type
	  	 [`(lambda ,Params ,Ret)		     		  
	  	  (let*-values 
		      ([(Es-types) (map expr->type Es)]
		       [(e0-type-free) (assoc E0 function-free-type-variable-bind-free-alist)]
		       [(e0-a-type)  (cadr e0-type-free) ]
		       [(e0-f-type)  (caddr e0-type-free) ]
		       [(types-correspond env-type-local-new unknown-typed-list-total-new)
			(env-type-match-partial-specialization	Params Es-types env-type-local  unknown-type-list)]
		       [(E0-type-a-specialization) (map (lambda (v) (aif (assoc v types-correspond) (cdr it) #f))  e0-a-type)]
		       [(E0-type-f-specialization) (map (lambda (v) (aif (assoc v types-correspond) (cdr it) #f))  e0-f-type)])
		    (set! env-type-local env-type-local-new)
		    (set! unknown-type-list unknown-typed-list-total-new)
		    (let* ([a-resolved? (andmap string? E0-type-a-specialization)]
			   [f-resolved? (andmap string? E0-type-f-specialization)]
			   [E0-cstr1
			    ;; When an argument cannot be resolved, omit the explicit
			    ;; template argument list and let C++ deduce it from the call.
			    (cond
			     [(null? e0-f-type)
			      (if a-resolved?
				  (str-a E0-cstr "<" (str-j E0-type-a-specialization ",") ">")
				  E0-cstr)]
			     [(and a-resolved? f-resolved?)
			      (str-a E0-cstr "<" (str-j E0-type-f-specialization ",") ">().operator()<" (str-j E0-type-a-specialization ",") ">")]
			     [f-resolved?
			      (str-a E0-cstr "<" (str-j E0-type-f-specialization ",") ">().operator()")]
			     [else E0-cstr])]
			   [ret
			;(str-a E0-cstr1 "(" (str-j (map cexp-cond-cast Es Params) ",") ")")
			    (str-a E0-cstr1 "(" (str-j (map cexp Es) ",") ")")
			    ])
		      (set! env-type-local env-type-local-old)
		      (set! unknown-type-list unknown-type-list-old )
		      ret) )]
		 [ _  (str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")]
	  	 ))
	(let ([E0-cstr (if (symbol? E0) (cname E0) (cexp E0))])
	    (if (null? Es)
		(str-a E0-cstr  "()")
		;(str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")

		(let ([E0-type (expr->type E0)])
		  (match 
		   E0-type
		   [`(lambda ,Params ,Ret)		     
		    (str-a
		     E0-cstr
		     "("
		     (str-j 
		      (map cexp-cond-cast Es Params) 
		      ",") ")" )]
		   [ _ 
		    (str-a E0-cstr "(" (str-j (map cexp Es) ",") ")")]
		   ))
		))
	)]
	  
	 [_ 
	  (error "unknown-expression in scm2cpp" expr-local)
	  (format " error_in_gen_cexp ~a " expr-local) ]
	 ))))

  (define (cexp-with-cast expr-local t-cast)
    (cond
     [(eq? t-cast Number)  (format "scm2cpp::get_number(~a)" (cexp expr-local))]
     [(optional-union-type? t-cast) => (lambda (X) (format "scm2cpp::optional_attach(~a)" (cexp expr-local)))]
     [ else (str-a (cpptype t-cast) "(" (cexp expr-local) ")" )]
     ))

  (define (cexp-cond-cast expr-local t-ref)
   (let ([te (expr->type expr-local)])
     (if (or (eq? te t-ref) (equal? te t-ref) 
	     ;(lset= equal? t-ref te) (lset= eq? t-ref te)
	     )
	 (cexp expr-local)
	 (if (and (eq? t-ref Number)
		  (or (number-type? te)
		      (type-unknown->number-any-union-type? te unknown-type-list))) 
	     (cexp expr-local)
	     (cexp-with-cast expr-local t-ref)))))

  (define (cexp-num e) 
    ;;(cexp e)
    (if (symbol? e)  
    	(cexp-cond-cast e Number)
    	(cexp e))
    )
    
  (define (cexp expr [t-ref NoType])
    ;(display (list "cexp " expr )) (newline)   
    (match
     expr
     ;; (cons a (delay b)) is a stream; wrap b in a C++11 lambda so it stays
     ;; delayed. Alpha conversion wraps an anonymous lambda as
     ;; (let ((L (lambda () ...))) L), so accept that shape too. This must sit
     ;; at the head of the match: a local-analysis variant and the function
     ;; name table both match cons first.
     [`(cons ,A (let ((,L (lambda () ,B ...))) ,L2))
      #:when (eq? L L2)
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::make_stream(~a,[=]() { return ~a; })"
	      (cexp A)
	      (cexp (if (= 1 (length B)) (car B) (cons 'begin B))))]
     [`(cons ,A (lambda () ,B ...))
      (c-includes-adds (list "<functional>" "\"scm2cpp.hpp\""))
      (format "scm2cpp::make_stream(~a,[=]() { return ~a; })"
	      (cexp A)
	      (cexp (if (= 1 (length B)) (car B) (cons 'begin B))))]
     [(? boolean? X) (if (equal? X #t) "true" "false" ) ]
     [(? number? X) (number->string X) ]
     [(? string? X) (string-append "\"" X  "\"") ]
     [(? char? X)   (string-append "'" (string expr)  "'") ]   

     [(? symbol? X)  (cname X)]
      ;; (if (eq? t-ref NoType)  (cname X)
      ;; 	  (let ([tx (vtype X)])	
      ;; 	    (if (equal? t-ref tx) (cname X)
      ;; 		(str-a (cpptyp t-ref) "(" (cname X) ")"))))]


     ;; Parenthesised, unlike the arithmetic default below: an operand
     ;; embedded in a further expression (e.g. (* 1.0 (remainder x n))) needs
     ;; its own precedence protected, since % and * bind at the same level
     ;; and are left-associative in C++, so an unparenthesised "a % b" folds
     ;; into a surrounding "c*a % b" as (c*a) % b rather than c*(a % b).
     [`(quotient ,N ,M) (format "(~a / ~a)"  (cexp-num  N) (cexp-num  M))  ]
     ;; remainder had no rule and fell through to the binary default.
     [`(remainder ,N ,M) (format "(~a % ~a)" (cexp-num  N) (cexp-num  M))  ]
     [`(modulo ,N ,M) (format "(~a % ~a)" (cexp-num  N) (cexp-num  M))  ]
     [`(atan ,X ,Y) (c-includes-add "<math.h>") (format "atan2(~a , ~a)"  (cexp-num  X) (cexp-num Y))  ]
     [`(abs ,X) (c-includes-add "<cmath>") (format "std::abs(~a)" (cexp-num  X)) ]
     [`(max ,X ,Y) (format "std::max( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [`(min ,X ,Y) (format "std::min( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [ (list (? op-float->float? Op) X) (c-includes-add "<math.h>") (format "~a(~a)" Op (cexp X ))  ]
     [`(not ,X) (format "!(~a)" (cexp X)) ]
     ;; and and or become the C++ short-circuit operators, so the operands are
     ;; evaluated in the same order and only as far as needed.  With no operand
     ;; Scheme gives #t and #f respectively.
     [`(and) "true"]
     [`(or)  "false"]
     [`(and ,E ...) (format "(~a)" (string-join (map cexp E) " && "))]
     [`(or  ,E ...) (format "(~a)" (string-join (map cexp E) " || "))]
     [`(zero? ,X) (format "(~a == 0 )" (cexp-num  X)) ]
     ;; One argument is a separate case.  The variadic clause below joins the
     ;; operands with the operator, and string-join emits no separator when the
     ;; list holds a single element, so (- x) came out as (x): the negation was
     ;; dropped and no error was reported.  A one-argument + or * is indeed the
     ;; argument itself, but - negates and / takes the reciprocal.
     [`(- ,X) (format "(-(~a))" (cexp-num X))]
     [`(/ ,X) (format "(1.0/(~a))" (cexp-num X))]
     [`( ,(? op-num-num-num? Op) ,V-list ...)
      (string-append "(" (string-join (map cexp-num V-list) (symbol->string Op)) ")")]
     [`( ,(? op-num-num-bool? Op) ,X ,Y) 
      (when (equal? Op '=) (set! Op '==))
      (format "~a ~a ~a" (cexp X) Op (cexp Y))]
     ;; [`(lambda ,params ,E ... ) 
     ;;  (clambda expr (gensym 'lambda) #false #false) ]
     [`(set! ,X ,Y) (format "~a = ~a" (cexp X) (cexp Y) )]
     [`(display ,X)  (c-includes-add "<iostream>") (format "std::cout << ~a" (cexp X))]
     ['(newline)  (c-includes-add "<iostream>") (format "std::cout << std::endl") ]
     [`(vector-ref ,X ,N) (format "~a[~a]"  (cexp X) (cexp N))] 
     [`(vector-set! ,X ,N ,V)(format "~a[ ~a ] = ~a " (cexp X)(cexp N)(cexp V))]
     [`(vector-length ,X)
      (let ((x (
		;expr->expand-type
		expr->type
		X)))
	;(display (list 'vec-len-cexp X x))(newline)
	(match 
	 x
	 [`(make-vector ,N ,V) (format "~a" (if (number? N) N (cexp N)))]
	 [`(vector ,E ...) (format "~a" (length E))]
	 [ _ (format "vector_length(~a)" (cexp X))  ]))]	    
     ;; [`(make-vector ,N1 ,V1)]
     ;; [`(make-vector ,N ,V)  `(make-vector ,N ,(inf V)  )]
     [`(if ,E1 ,E2 ,E3)	(format "( ( ~a ) ? (~a) : (~a) )" (cexp E1) (cexp E2) (cexp E3)) ]
     [`(cond (,X ,E) ...)
      ;(display (list 'cond-cexp X E))(newline)
     	(format 
     	 "( ~a )"
     	 (str-j 
     	  (append
     	   (map
     	    (lambda (x y)(format "( ~a ) ? ( ~a )" (cexp x)(cexp y))) 
     	    (drop-right X 1) (drop-right E 1) )
     	   (list (apply str-a
     	    (cons (format "( ~a )" (cexp (last E)))
     		  (make-list (- (length E) 1) ")")))))
     	  " : ( "))]
     [(or `(define ,(? symbol? X) (make-vector ,(? number? N) ,V))
	  `(define ,(? symbol? X) (make-list ,(? number? N) ,V)))
      ;;(display (list "def make vec " X N V expr)) (newline)(display (list (cpptype (expr->type V) ) (cpptype (expand-type X env-type-local) ))) (newline)
      ;; The vector representation follows the back end. Thrust needs the data
      ;; in device memory, and offloading a boost::array is not portable, so
      ;; under gpu a plain array is emitted and filled by a loop.
      (cond
       [(equal? (getenv "SCM2CPP_PARALLEL") "thrust")
	(c-includes-add "<thrust/device_vector.h>")
	(format "thrust::device_vector<~a> ~a(~a,~a)"
		(sexp->cpptype V) (cexp X) N (cexp V))]
       [(equal? (getenv "SCM2CPP_PARALLEL") "gpu")
	(format "~a ~a[~a]; for(int scm2cpp_i=0;scm2cpp_i<~a;scm2cpp_i++) ~a[scm2cpp_i]=~a"
		(sexp->cpptype V) (cexp X) N N (cexp X) (cexp V))]
       [else
	(c-includes-adds (list "<boost/array.hpp>"  "<boost/assign.hpp>"))
	;;(format "boost::array<~a,~a> ~a=boost::assign::list_of<~a>().repeat(~a,~a)"  (sexp->cpptype V) N (cexp X) (sexp->cpptype V) N (cexp V) )
	(format "boost::array<~a,~a> ~a=boost::assign::list_of(~a).repeat(~a,~a)"
		(sexp->cpptype V) N (cexp X)
		(cexp V) (- N 1) (cexp V) )])
      ]
     [(or 
       `(define ,(? symbol? X) (make-vector ,N ,V))
       `(define ,(? symbol? X) (make-list ,N ,V)))
      (c-includes-add "<vector>")
      ;; N is an expression here, not a literal, and must be translated;
      ;; it reached the output as a raw s-expression before.
      (format "std::vector<~a> ~a(~a,~a)" (sexp->cpptype V) (cexp X) (cexp N) (cexp V))]
     [(or `(make-vector ,(? number? N) ,V)
	  `(make-list ,(? number? N) ,V))
      (c-includes-adds (list "<boost/array.hpp>" "<boost/assign.hpp>"))
      ;(format "boost::array<~a,~a>(boost::assign::list_of<~a>().repeat(~a,~a))"  (sexp->cpptype V) N (sexp->cpptype V) N (cexp V) )]
      (format "boost::array<~a,~a>(boost::assign::list_of(~a).repeat(~a,~a))"  (sexp->cpptype V) N (cexp V) (- N 1) (cexp V) )]
     [(or 
       `(make-vector ,N ,V)
       `(make-list ,N ,V))
      (c-includes-add "<vector>")
      (format "std::vector<~a>(~a,~a)" (sexp->cpptype V) N (cexp V))]
     ;; Build a (list e ...) value. std::list rather than std::vector, because
     ;; uniform_sequence_to_boost_ptr_sequence_view maps a vector to
     ;; ptr_vector, which has no push_front, so cons would not compile.
     [`(list ,params ...)
      (let ([ts (map (lambda (p) (sexp->cpptype p)) params)])
	(cond
	 [(null? params)
	  (c-includes-add "<list>")
	  "std::list<int>()"]
	 [(list-all-equal? ts)
	  (c-includes-add "<list>")
	  (format "std::list<~a>{~a}" (car ts) (str-j (map cexp params) ","))]
	 [else
	  (c-includes-add "<boost/fusion/include/list.hpp>")
	  (format "boost::fusion::make_list(~a)" (str-j (map cexp params) ","))]))]
     [`(define ,(? symbol? X) ,E) (format "~a ~a = ~a"  (sexp->cpptype X)  (cexp X) (cexp E)) ]
     [`(quote ,(? symbol? X) ) (format  "string_to_symbol(\"~a\") " X) ]

     [`( ,(? cpp-function-name-correspond-alist? f) ,E ... )
      ;(display (list f E))(newline) 
      (format "~a (~a)" 
	      (cpp-function-name-in-correspond-alist f)
	      (string-join (map cexp E) " , "))
     	      ;(map cexp E)
      ]

     [_ (cexp-with-local-analysis expr t-ref)]
     ))
  (define (cstat expr 
		 [cterm-stat cstat-semi]  ;cstat-ret
		 [cterm-exp cexp] ;cexp-ret 
		 )
    ;(display (list "cstat "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (match 	 
     expr
     [(or `(cond ,E ...) `(begin (cond ,E ...))) 
      (let* ((clauses (drop-right E 1))
	     (last-clause  (last E))
	     (cond-cexp-fn (lambda (x) (cexp (car x))))
	     (cconds (map cond-cexp-fn clauses))	     
	     (clast 
	      (match 
	       last-clause
	       [`(else ,E1 ... ) 
		(begin-inc-lv
		 (str-a "{"(cterm-stat `(begin . ,E1)) "}"))]
	       [ _ (format "if(~a){~a}" (cexp (car last-clause))
			   (begin-inc-lv
			    (cterm-stat `(begin . ,(cdr last-clause)))
			    )
			   )
		   ])))
	(begin-dec-lv
	 ;(display (list "cstat-cond " cconds ))(newline)
	 (str-j 
	  (append
	   (map (lambda (c x)(format "if(~a){~a}" c (cterm-stat `(begin . ,(cdr x))))) cconds clauses)
	   (list clast))
	  " else ")))]
     [(or `(if ,E1 ,E2 ,E3) `(begin (if ,E1 ,E2 ,E3)))	
      (format "if( ~a ) { ~a } else { ~a }" 
	      (cexp E1) (begin-inc-dev-lv (cterm-stat E2))  (begin-inc-dev-lv (cterm-stat E3)) )]
     [(or `(if ,E1 ,E2)  `(begin (if ,E1 ,E2)) `(when ,E1 ,E2) `(begin (when ,E1 ,E2)))
      (format "if( ~a ){~a}" (cexp E1) (begin-inc-dev-lv (cterm-stat E2)) ) ]
     [(or `(unless ,E1 ,E2) `(begin (unless ,E1 ,E2)))
      (format "if( ~a ){}else{~a}" (cexp E1) (begin-inc-dev-lv (cterm-stat E2) )) ]
     [`(begin ,E ...)
      ;(begin-inc-dev-lv
      (let* ([saved integ-share-plan]
	     [plan (integ-plan-sequence E)])
	(set! integ-share-plan (append plan saved))
	(let ([r (str-a
		  (apply str-a (map cstat-semi (drop-right E 1)))
		  ;; (cexp-ret (last E))
		  (cterm-stat (last E)))])
	  (set! integ-share-plan saved)
	  r))]
     ;; [`(begin ,E ...) (cstat-semi expr)]
     [`(define (,F ,params ...) ,E ... ) 
      (clambda 
       (cons 'lambda (cons params E))
       F F #false)]
     [`(let ((,L (lambda ,params ,E ... ))),L)
      (cexp-with-local-analysis expr)]
     [`(let (,V ... ) ,E ...)
      (let* ((cvarsinit (map (lambda (e) (cexp `(define ,(car e) ,(cadr e)))) V)))
	(str-a (str-j cvarsinit ";") ";"
	       (begin-inc-dev-lv 	       
		(cterm-stat `(begin . ,E)))))]
     [`(do  ,bindings ,pred ,E ... )
      ;(display (list 'do-cpp bindings pred E))(newline)	(format "for( ~a ;;~a )" (str-j cvarsinit ",") (str-j cvarsnext ","))
      (let* ((ii (integ-boxsum-nest expr))
	    (thr (and (not ii) (thrust-loop bindings pred E)))
	    (prag (parallel-pragma))
	    (cvarsinit (map (lambda (e) (cexp `(define ,(car e) ,(cadr e)))) bindings))
	    (cvarsnext (map (lambda (e) (cexp `(set! ,(car e) ,(caddr e)))) bindings))
	    (cend (match (car pred)
			 [`(not ,X) (cexp X)]
			 [_ (str-a "!(" (cexp (car pred)) ")")]))
	    (cret (if ( >  (length pred) 1)
		      (cexp (cadr pred)) ""))
	    (outer in-parallel-loop)
	    ;; The body is generated with the flag set, so that a nested loop
	    ;; does not get a directive of its own.
	    (cb (begin
		  (set! in-parallel-loop #t)
		  (let ([r (if (null? E) ""
			       (begin-inc-dev-lv
				(str-a "{" (cstat-semi `(begin . ,E)) "}")))])
		    (set! in-parallel-loop outer)
		    r))))
	(if ii ii
	(if thr thr
	(if (or (equal? cterm-stat cstat-semi) ( <  (length pred) 2))
	    (str-a prag
		   (format "for( ~a ; ~a ; ~a )" (str-j cvarsinit ",") cend (str-j cvarsnext ","))  cb)
	    (str-a 
	     (format "for( ~a ;; ~a )" (str-j cvarsinit ",") (str-j cvarsnext ","))
	     (format "if( ~a ){ ~a }else{ ~a }  " (cexp (car pred)) (cterm-stat (cadr pred)) (begin-inc-dev-lv (cstat-semi `(begin . ,E)))))))))]
     [_ (cterm-exp  expr)]
     ))
  (define (cexp-ret expr)
    ;(display (list "cexp-ret "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (let* ((o (cexp expr))
	   (o2 (format "~a return ~a ;" (stack-top pre-cexp) o)))
      (stack-set! pre-cexp 0 "") 
      o2))
  (define (cstat-semi expr)
    ;(display (list "cstat-semi "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (match 
     expr
     [`(begin ,E ...)
      (let* ([saved integ-share-plan]
	     [plan (integ-plan-sequence E)])
	(set! integ-share-plan (append plan saved))
	(let ([r (apply string-append (map cstat-semi E))])
	  (set! integ-share-plan saved)
	  r))]
     [ _
       (let* ((o (cstat expr))
	      (o2 (format "~a ~a " (stack-top pre-cexp) o)))
	 (stack-set! pre-cexp 0 "")
	 ;(set! pre-cexp "")
	 (format "~a ;~n" o2)
	  )]))
  (define (cstat-ret expr)
    ;(display (list "cstat-ret "  (length (unbox pre-cexp)) expr (cadr (unbox pre-cexp))  ))(newline)
    (let* ((o (cstat expr cstat-ret cexp-ret))
	   (o2 (format "~a ~a" (stack-top pre-cexp) o)))
      (stack-set! pre-cexp 0 "")
      o2))

      ;(cstat expr cstat-ret cexp-ret))
  (define (cdefs expr)
    ;(display (list "cdefs " expr))(newline)
    (match 
     expr	 
     [`(define (,params ...) ,E ... ) (cdeffun expr)]
     ;; Global definitions must precede the function bodies, which go to the
     ;; header; writing them to the source file inverts the declaration order.
     [`(define ,(? symbol? X) ,E)
      (set! port-o port-h)
      (pout (cstat-semi expr))]
     [_
      ;(display (list "cdefs last " expr))(newline)
      (set! port-o port-c)
      (pout (cstat-semi expr))]))
  (define (cdeffun expr)
    (display (list "cdeffun0 " expr))(newline)
    (hout (format "~n"))     (cout (format "~n"))
    ;(display (list 'cdeffun1  expr (function-name expr) (vtype (function-name expr) )))(newline)
    (let-values ([(expr1 alpha1 free1)  (alpha-conv expr)])
      ;(display (list 'cdeffun2  expr1 alpha1 free1 ))(newline)
      (let* ((free1inv ( envinvert free1))
	     (alpha1inv ( envinvert alpha1))
	     (freevars (map car free1inv))
	     (vars1  (map car alpha1inv))
	     (t-vars1  (filter non-fix-type? vars1))	     
	     (lambda-ret-type
	      (last (cdr (vtype (function-name expr) ))))
	     [all-vars-return2 (append 	vars1 freevars (list lambda-ret-type))]
	     [all-vars-return1 (append 	vars1          (list lambda-ret-type))]
	     )
	;(display (list 'cdeffun3 t-vars1))(newline)
	(display (list 'all-vars-return1 all-vars-return1))(newline)
	(set! current-template-vars	       
		(remove-duplicates
		 (if (non-fix-type? lambda-ret-type)
		     (append (list lambda-ret-type )  t-vars1)
		     t-vars1))
		)
	(set! current-template-types
	      (vars-typeenv-unknown->unknown-types all-vars-return1 env-type-local unknown-type-list))

	;(display (list 'cdeffun2 lambda-ret-type ))(newline)
	;(display (list 'cdeffun2 lambda-ret-type  (sexp->cpptype lambda-ret-type)))(newline)
	(match
      	 expr
      	 [`(define (,F ,params ...) ,E ... )
          ;(display (list "def params0 " F  params lambda-ret-type E))
	  ;(display (list "def params "  params lambda-ret-type (sexp->cpptype lambda-ret-type)))
	  (if (null?  current-template-vars) (set! port-o port-c) (set! port-o port-h))
	  (let* ((mutated-params
		  ;; The parameters this function may write, by name; the
		  ;; summary stores indices so that alpha renaming cannot
		  ;; desynchronise it. A function absent from the summary
		  ;; (renamed, say) yields #f -- no const information --
		  ;; rather than an empty list, which would claim that
		  ;; nothing is written.
		  (let ([idxs (hash-ref mutation-summary F #f)])
		    (and idxs
			 (filter-map (lambda (i) (and (< i (length params)) (list-ref params i)))
				     idxs))))
		 (func-def-cstr (format "~a \n ~a(~a)"  (cpptype lambda-ret-type) (cname F) (svars->cargs params #false mutated-params)))
		 (cfunstr	    
		  (format 
		   "\n ~a \n ~a \n {~a}" 
		   ;(svars->ctemplatedef current-template-vars) 
		   (types->ctemplatedef-used current-template-types func-def-cstr)
		   func-def-cstr 
		   (begin
		     (inc-lv)
		     (cstat-ret (cons 'begin E)) ;;func body
		     )
		   ))
		 (cfunstr2 (str-a pre-cfun cfunstr)))
	    ;(display (list "cdeffun3"  current-template-vars))(newline)
	    (dec-lv)
	    (c-fwd-decl-add
	     (format "~a~a;~n"
		     (types->ctemplatedef-used current-template-types func-def-cstr)
		     func-def-cstr))
	    (set! pre-cfun "")
	    (pout cfunstr2)
	    )	
	  ]
	 [_ 
	  ;; (error "unknown-expression in scm2cpp-def" expr)
	  (cstat-semi expr)
	  ;(format " error_in_gen_cexp-def ~a " expr) 
	  ]
	 )))
    )

  (c-includes-add "\"scm2cpp.hpp\"" )


					;(cstat expr-alpha)
  ;(display (list 'expr-alpha expr-alpha)) (newline)
  ;; (display env-alpha-inv)
  ;; (display env-free-inv)
  ;; (display env-init-type )
  ;(display env-type) (newline)
  ;; (define (tmpf a b)  (display env-type-local) (+ a b))
  ;; (display (tmpf 1 10)) 
  ;; (cexp-with-local-analysis  '(let ((z (lambda (x127 y128) (+ x127 y128)))) (lambda (u v) x (+ u v))))

  ;;(cdeffun expr-alpha)
  ;; (cdeffun (cadr expr-alpha))  
  ;; (when env-ret-type 
  
  ;; Which function may write which parameter, needed both for the const
  ;; parameters below and for the write-free spans the sharing of
  ;; summed-area tables depends on.
  (compute-mutation-summaries! expr-org)

  (map
   cdefs (cdr expr-alpha))

  ;(string-append 
  (string-append
   (apply string-append
	  (map (lambda (x)
		 (list->string (append (string->list "#include" ) '(#\tab) (string->list  x ) '(#\newline))))
	       c-includes))
   (format "~n")
   (apply string-append c-fwd-decls))
           
  )




					;(display 
					;(declare-names  (call-with-input-file "scm2c.typ" read))
					; ) 

;(define scmcode '(define (f x) y ))

(define (scm2cpp-match-values scmcode)
  (let* ((cppcode "")
         (hppcode "")
	 (includes "")
	 )
    (set! 
     hppcode 
     (call-with-output-string 
      (lambda (port-h)
	(set! cppcode
	      (call-with-output-string       
	       (lambda (port-c)
		 (set! includes
		 (scm2cpp-match-port scmcode port-h port-c))))))))
    (set! hppcode  (string-append includes hppcode ))
  (values hppcode cppcode)))

(define (cpp-code-string-indent cppcode-str)
  ;; A fixed shared path here meant concurrent translations (as when
  ;; run-tests.sh and a manual invocation overlap) could each overwrite the
  ;; other's file mid-astyle-run, so one process could read back the other's
  ;; program. A fresh temporary file per call avoids that.
  (let ([tmp (make-temporary-file "scm2cpp-indent~a.cpp")])
    (display-to-file cppcode-str tmp #:exists 'replace)
    (port->string (car (process (format "astyle ~a" tmp))))
    (let ([result (file->string tmp)])
      (delete-file tmp)
      result)))

;; (define tmp-cppstr
;; "
;; template< typename XType >  double f( XType  x  ,  double  y ) {
;;  struct let127 { 
;;  double  &  y;
;;   let127( double  &  y ):y(y)  {} 
;;  double operator()( int  v  ,  double  u  ) 
;;  {  u = 20  ;
;;     v =  \"aaaaa\"
;;  return (u+y) ; } }  ;
;;  return (10+let127(y)(3,10)) ;}
;; ")
;; (display (cpp-code-string-indent tmp-cppstr))



(define (scm2cpp-match-list scmcode-pre-expand-macro-str declarationstr )
  ;;(display (scheme-code-string-macro-expand scmcode-pre-expand-macro-str))
  (set!declarations '())
  (set!unknown-type-list '())
   ;(declare-names declarationstr)
  (declare-names 
   (call-with-input-string 
    declarationstr
    (lambda (p) (read p)))) 
  (call-with-values 
      (lambda ()
	(scm2cpp-match-values
	 ;; The search-based rewriter runs after the named-let rewrite, so
	 ;; loops that rewrite created are candidates too. Off unless asked.
	 ((if (rewrite-search-enabled?) rewrite-search values)
	 (rewrite-named-let
	  (call-with-input-string 
	  (string-append 
	   "(begin "
	   ;;scmcodestr
	   ;;scmcode-pre-expand-macro-str	   
	   (scheme-code-string-macro-expand scmcode-pre-expand-macro-str)
	  ")")
	   (lambda (p) (read p)))))))
    (lambda (h c)
      (list 
       (cpp-code-string-indent h)
       (cpp-code-string-indent c) "")
      ))
  )



(define (scm2cpp-match-display scmcode)
  (call-with-values 
      (lambda ()(scm2cpp-match-values `(begin ,scmcode))) 
    (lambda (h c) 
      (display h) (newline) 
      (display c) (newline)))
  )



;; ;(define tmp-exp (s-read "fft.sc"))
;; (define tmp-exp (s-read "fft-sub1.scm"))
;; ;(set! tmp-exp (cons 'begin tmp-exp))


;; (define tmp-exp-str (with-output-to-string  (lambda () (map display tmp-exp))))
;; ;;(display tmp-exp-str) (newline)


;; (define tmp-exp-str
;; (cond ((not (= n (let loop ((i m) (p 1)) ;Qobi
;; 		    (if (zero? i) p (loop (- i 1) (* 2 p))))))
;; 	 (display 'aaaa)
;; 	 (newline)))
;; )

;; (define tmp-exp-str
;; "
;; (define (f)
;;     (set! x 2)
;;     (cond
;;      ( 
;;       (not 
;;        (= n 
;; 	  (let loop ((i m) (p 1)) 
;; 	    (if (zero? i) p (loop (- i 1) (* 2 p))))
;;        ))
;;     x)
;;      )
;; )
;; "
;; ;; "(define (f x y) 
;; ;;     (if (> x y) 100 3))"
;; )

;; (define tmp-exp-str
;;   "(if z x y)"
;; )


;; ;; ;(define tmp-exp-str  "(+ x 3)")
;; ;(define tmp-exp-str  "(define (f x) x)")
;; (define tmp-exp-str  "(define (f x) (+ 1 x))")
;; ;(define tmp-exp-str  "(define (f x y) (+ y x))")


;; (map display
;; (scm2cpp-match-list 
;; tmp-exp-str
;;  "(
;;  (\"*int\" int) 
;;  (\"main\" int) 
;; )"
;; )
;; )



(define tmp-exp-str
"
(define (sqrt-double x)
  (sqrt-iter-double 1.0 x))


(define (sqrt-iter-double guess x)
  (if (good-enough? guess x)
      guess
      (sqrt-iter-double (improve guess x)
                 x)))


(define (good-enough? guess x)
  (< (abs (- (square guess) x)) 0.001))


(define (improve guess x)
  (average guess (/ x guess)))


(define (average x y)
  (/ (+ x y) 2.0))


(define (square x) (* x x))


(display (sqrt-double 9.0) )

;; (define (main )
;;    (display (sqrt-double 9) )
;;    ;(display (sqrt-double 8) )
;;    (newline)
;;    0
;; )

")


;; (map display
;; (scm2cpp-match-list 
;; tmp-exp-str
;;  "()"
;; )
;; )










;; ;; "(define (f x y) 
;; ;;     (if (> x y) #t #f)) "


;; ;; "(define (f x y) 
;; ;;     (+ 10 (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1))))"

;; ;; "(define (f x y) 
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1)))"

;; ;; "(define (f) 
;; ;;   (define v (make-vector 3 12.0))
;; ;;   )"

;; ;; "(define (f) 
;; ;;   (make-vector 3 12.0))
;; ;;   "


;; ;; "(define (f) 
;; ;;   (define v (make-vector 3 12.0))
;; ;;   (vector-set! v 2 2.0)
;; ;;   (vector-ref v 3)  
;; ;;   v
;; ;; )"


;; ;; "(define (f x y)
;; ;;    (define (h u v) (* u v))
;; ;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;; ;;       (set! u 20)  
;; ;;       (+ x y))
;; ;;     )
;; ;;     (if (> x y) x y)
;; ;;     (+ 10 (if (> x y) x y))
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)) 
;; ;;     (+ 20 (cond 
;; ;;      ((> x y) 3) 
;; ;;      ((< x y) 10)
;; ;;      (else 1)))
;; ;;     (+ (f 3 5) (h x y) (g x y) )
;; ;;  )
;; ;; (define (g x y)       (+ x y))
;; ;; (define (main)(f 1 2)  0)
;; ;; "

;; ;;" (define (f x y) 
;; ;;    (define (h u v) (* u v))
;; ;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;; ;;       (set! u 20)  
;; ;;       (+ x y))
;; ;;     )
;; ;;     (if (> x y) x y)
;; ;;     (+ 10 (if (> x y) x y))
;; ;;     (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)) 
;; ;;     (+ 20 (cond 
;; ;;      ((> x y) (set! x 2) 3) 
;; ;;      ((< x y) (set! x 2) 10)
;; ;;      (else (set! x 2) 1)))
;; ;;     (+ (f 3 5) (h x y) (g x y) )
;; ;;  )
;; ;; (define (g x y)       (+ x y))
;; ;; (define (main)(f 1 2)  0)
;; ;; "
;;  "
;; (
;;  (\"*int\" int) 
;;  (\"main\" int) 
;; )
;; "
;; )
;; )

					;(curry scm2cpp-match-values '(define (f x) (+ x y)))

;; (scm2cpp-match-display '(define (f x y) (set! u 20)  (+ x y)))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+ 10 (let ( (v (+ x 3)) (u (* 10 y))) 
;;       (set! u 20)  
;;       (+ x y))
;;     )
;;  ))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+ 10 (let ( (v 3) (u 10)) 
;;       (set! u 20)  
;;       (+ u y))
;;     )
;;  ))

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (+  10 lambda (x y) (+ x y)) 13)  
;;     )
;;  )

;; (scm2cpp-match-display 
;;  '(define (f x y) 
;;     (let ((z (lambda (x y) (+ x y))) )
;;       (lambda (u v) x (+ u v))
;;     ;0
;;     )))





;; (scm2cpp-match-display '(define (f x) (set! y 10) (+ y x )))

					;(display (scm2cpp-match '(let ((x u)(y 2))(set! z 19) (+ v 29 ))))
					;(scm2cpp-match '(let ((x 20)(y 2))(set! x 19)) )

					;(alpha-free->type-env '((a-int . a-int )) '((b-int . b-int ))) 
					;(scm2cpp-match 'x)
					;(scm2cpp-match '(+ x-int y-int 10 ))
					;(scm2cpp-match '(> x-int y-int ))
					;(scm2cpp-match '(set! v (+ x-int y-int 10 )))
					;(scm2cpp-match '(if (> x y ) (set! x 20 ) (set! y 30)))
					;(display (scm2cpp-match '(if (> x y ) (begin (set! x 20 ) (set! y 30) )  (set! y 1 )))) 
					;(display (scm2cpp-match '(begin (set! x 20 ) (set! y 30))))

					;(scm2cpp-match '(lambda (x) (+ x 10)))
					;(display (scm2cpp-match '(lambda (x) (+ x y))))
					;(display (scm2cpp-match '(define (f x) (+ x y))))
					;(display (scm2cpp-match '(define (f) (+ x y))))

					;(display "aa")
					;(newline)
					;(string-join '("one" "two" "three" "four") " potato ")







					;(scm2cpp-match '(define (f x-int y-int ) (display x) (display y) (+ x-int y-int )) )






;; (define %cpp-expression 
;;   (%rel 
;;    ( Exp O  O1  O2 Op OOp
;;      Pre Post S1 S2 S3 
;;      Clauses Body 
;;      X Y Z A B A-list V-list F
;;      XX YY 
;;      Tmp
;;      )
;;    [( X Y) (%string? X)  (%is Y (string-append "\"" X  "\"")) ] 
;;    [( X Y) (%number? X) (%is Y (number->string X)) ] 
;;    [( X Z) (%char? X) (%is Y (string X)) (%cpp-expression Y Z) ]
;;    [( X O) (%symbol? X)  (%is O (symbol->string X))  ]

;;    [( `(,Op ,X ,Y )  O) 
;;     (%member Op op-num-num-num) 
;;     (%cpp-expression X XX)
;;     (%cpp-expression Y YY)
;;     (%cpp-expression Op OOp)
;;     (%is O (string-append "(" XX OOp YY ")")) 
;;     ]

;;    ;; [( `(,Op . ( ,X . ( ,Y . ,Z )))  O) 
;;    ;;  (%member Op op-num-num-num) 
;;    ;;  (%cpp-expression    )
;;    ;;  (%cpp-expression Y YY)
;;    ;;  (%cpp-expression Op OOp)
;;    ;;  (%is O (string-append "(" XX OOp YY ")")) 
;;    ;;  ]

;;    ))

;; (%which (O) ( %cpp-expression "aaaa"    O))
;; (%which (O) ( %cpp-expression #\newline O))
;; (%which (O) ( %cpp-expression 12        O))
;; (%which (O) ( %cpp-expression 'a        O))
;; (%which (O) ( %cpp-expression '(+ a (* b 6 ))        O))


;; (define (cpp-expr expr)
;;   (match
;;    expr
;;    [(? number? X) (number->string X) ]
;;    [(? string? X) (string-append "\"" X  "\"") ]
;;    [(? char? X)   (string-append "'" (string expr)  "'") ]   
;;    [(? symbol? X) (symbol->string X)  ]
;;    [`( ,(? op-num-num-num? Op) ,V-list ...) 
;;     (string-append 
;;      "("
;;      (string-join (map cpp-expr V-list) (symbol->string Op))
;;      ")")
;;     ]

;;    ;; [_ ('else expr)]
;;    )
;; )

;; ;; ;(constant? 12)
;; ;; (cpp-expr "aaaa")
;; ;; (cpp-expr 'a)
;; ;; (cpp-expr 12)
;; ;; (number? 12)
;; ;; (char? #\newline)
;; ;; (cpp-expr  #\newline )
;; ;; (cpp-expr  (string #\newline ))
;; ;; (cpp-expr '(+ a (* b 6 )) ) 



;; ;; (define %scm2cpp-str
;; ;;   (%rel 
;; ;;    ( Exp Alpha Free Type Out
;; ;;      Pre Post S1 S2 S3 
;; ;;      Clauses Body 
;; ;;      X Y Z A B A-list V-list F
;; ;;      Tmp
;; ;;      )
;; ;;    [( X Alpha Free Type Y) (%string? X)  (%is Y (string-append "\"" X  "\"")) ] 
;; ;;    [( X Alpha Free Type Y) (%number? X) (%is Y (number->string X)) ] 
;; ;;    [( X Alpha Free Type Z) (%char? X) (%is Y (string X)) (%scm2cpp-str Y Alpha Free Type Z) ]
;; ;;    ))

;; ;; (%which (O) ( %scm2cpp-str "aaaa"    null null null O))
;; ;; (%which (O) ( %scm2cpp-str #\newline null null null O))
;; ;; (%which (O) ( %scm2cpp-str 12        null null null O))




;; (define (cpp-stat expr)
;;   (match 
;;    expr
;;    [ `(set ,X ,Y)  (format "~a = ~a " X (cpp-expr Y))]

;;    ))

;; (cpp-stat '(set x (+ a 12 (* 2 b))))

;; (let* (
;;        (lambda-name (gensym 'lambda))
;;        (lambda-obj-name (gensym lambda-name))
;;        )

;;   (format 
;; "struct ~a{ ~a{} void operator()(){
;; return x
;; }   
;; }~a
;; " lambda-name lambda-name lambda-obj-name)
;; )








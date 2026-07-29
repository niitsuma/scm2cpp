#lang racket

(provide


 quick-derive-return-type
 derive-type
 infer-type-from-org-expr

 ;var-env->type
 ;var-non-fix-type?
 ;type->ctype
 
)

;(require srfi/1)
(require (only-in srfi/1
	 lset-difference
	 lset=
	 lset-union
	 lset-adjoin
	 fold
	 ))
(require mzlib/defmacro)


;(require cKanren)
(require (only-in cKanren
                    var 
		    conda
		    conde
		    membero
		    ==
		    =/=
		    fresh
		    succeed
		    ;fail
		    run*
		    conso
		    never-trueo
		    ))


(require "ck-util.scm")


(require "alist-util.scm")
(require "cl-util.scm")
(require "list-util.scm")
(require "onlisp.scm")

;(require "./cl2scm/bsort.scm")


(require "schlep-name.scm")
(require "alpha-conv.scm")
(require "type-symbols.scm")

(require "type-infer-util.scm")
(require "type-infer-hm.scm")
(require "type-ck-util.scm")

(require "depend-analysis.scm")






;; (define (more-general-type t-var t-ref [env null])
;;   (cond 
;;    [(and (number-type? t-var) (number-type? t-ref))
;;       (more-general-number-type t-var t-ref )]
;;    [(and (number? t-var) (number-type? t-ref)) t-var]
;;    [(and (number? t-ref) (number-type? t-var)) t-ref]
;;    [(and (number? t-ref) (number? t-var)) (max t-ref t-var)]
;;    [(and (equal? t-ref Void) t-var)]
;;    [(and (equal? t-var Void) t-ref)]
;;    ;[(and (rigid-type? t-var) (not (rigid-type? t-ref))) t-ref]
;;    ;[(and (rigid-type? t-ref) (not (rigid-type? t-var))) t-var]
;;    [else t-var]
;;       ))

;; (define (most-general-type lst [env null])
;;   (foldl (lambda (v r) (more-general-type v r env)) (car lst ) (cdr lst) ))

;; (define (more-special-type t-var t-ref )
;;   (if (and (number-type? t-var) (number-type? t-ref))
;;       (more-special-number-type t-var t-ref )
;;       t-var
;;       ))


;; (define (sexp-have-unknown-type? sexp env)
;;   (if (atom? sexp)
;;       (if (member sexp scm2cpp-primitives)
;; 	  #f
;; 	  (var-non-fix-type? sexp env))
;;       (
;;        ;; cons 
;;        or
;;        (sexp-have-unknown-type? (car sexp) env)
;;        (sexp-have-unknown-type? (cdr sexp) env))))

;; (define (vector-mutable-in-sexp? sexp v)
;;   (match
;;    sexp
;;    [`(vector-set! ,X ,N ,V) (if (equal? X v) #t 
;; 				 (vector-mutable-in-sexp? V v))]
;;    [(? pair?)
;;     (or
;;      (vector-mutable-in-sexp? (car sexp) v)
;;      (vector-mutable-in-sexp? (cdr sexp) v))]
;;    [_ #f]))

				


(define (quick-derive-return-type expr env)
  

   (match
     expr
     ['true Bool]
     ['false Bool]
     [(? boolean?) Bool]
     [(? exact-integer?) Int]
     [(? double?) Double ]
     [(? pure-complex?) Complex]
     [(? pure-rational?) Rational ]
     [(? number?) Number]
     [(? string?) String]
     [(? char? e) Char ]
     [(quote (? symbol? )) Symbol]
     [ (list (? op-float->float? ) X) Double]
     [ (list (? op-float->float? ) E ... ) Double]
     [`( ,(? op-num-num-bool? o ) ,E ...) Bool]
     [`( ,(? op-num-num-num? o ) ,E ...) Number]
     [(? symbol? X) (cdr (assoc X env))]

     [_  
      (let*-values ([(type1 ret1 unk1) (derive-type expr env)])
	ret1
	)]
))


	     
  


(define (derive-type expr-input env-match [unknown-typed-list '()] [ck-constraints-init '()] ) 
		     ;alpha free)

  (define =or =<=force)


  ;; (set!
  ;;  ck-constraints-rigid
  (define-values
    (env-ck 
     ck-constraints-rigid)
    (type-env-match->type-env-ck-var-constraints env-match unknown-typed-list  ck-constraints-init)
  )

  ;(define ck-problems '())
  ;(define ck-constraints-rigid '())
  (define (add-ck-constraints p)(set! ck-constraints-rigid (cons p ck-constraints-rigid)))

  ;(define env-ck1 (type-env-match->type-env-ck-var env-match unknown-typed-list))
  ;(define-values (env-ck2 env-union) (type-env->env-union-env-values env-ck1))
  ;(define env-union-ck-var (map (lambda (kv) (cons (car kv) (var (car kv)))) env-union))
  ;(define env-union-ck (cl:sublis env-union-ck-var env-union))
  ;(define env-ck (cl:sublis env-union-ck-var env-ck2))

  ;(for-each
  ; (lambda (kv)  (add-ck-constraints (membero (car kv) (cddr kv) )))
  ; env-union-ck)

  (define ck-constraints-later '())
  (define (add-ck-constraints-later p)(set! ck-constraints-later (cons p ck-constraints-later)))


  (define function-return-type-list '() );;recursionable-type-list
  (define (add-return-type t)
    (lstack-push! t function-return-type-list)
    ;(set! function-return-type-list (cons t function-return-type-list))
    ;(display (list 'add-return-type t function-return-type-list))(newline)
    )


  ;(define unknown-typed-list '())
  (define (unknown-typed? v)(member v unknown-typed-list))

  (define number-typed-list '())
  (define (number-typed? v)(member v number-typed-list))

  (define any-typed-list '())
  (define (any-typed? v)(member v any-typed-list))

  (define (number-typed-union-arg? expr) 
    (null? (lset-difference equal?
      (lset-difference equal? expr number-type-order-list) 
      number-typed-list))  )
  (define (bool-optinal-union-arg? expr) 
    (lset= equal? (list Optional)
	   (lset-difference equal? expr any-typed-list)))

  (define (union-type-arg->result-type arg) (if ( = (length arg) 1) (car arg)  (cons Union arg)))
  (define (refine-union-type-sexp expr)
    (match
     expr
     [ (? null?) expr]
     [ (? atom?) expr]

     ;;;;;;(union number x) -> x
     ;; [`(,(? union-symbol? U) . ,(? number-typed-union-arg? X) )
     ;;  (union-type-arg->result-type (lset-difference equal? X number-type-order-list))]
     ;; ;[`(,(? union-symbol? U) . ,(? bool-optinal-union-arg? X) ) Bool]

     [ (? pair?)
       (cons 
	(refine-union-type-sexp (car expr))
	(refine-union-type-sexp (cdr expr)))
       ]
     [ _ expr]
     ))

  

  (define nullset #())
  (define list->set list->vector)
  (define (enset e) (list->set (list e)))
  (define voidset (enset Void))


  (define (set+ l1 . ll) 
    (apply vset-union (cons equal? (cons l1 ll))))

  ;(define (env-add-var v) (set! env (alist-cons-update v v env))) 
  (define (env-add-var v) (set! env-ck (alist-cons-update v (var v) env-ck))) 


  (define undef-vars '())
  (define (tmp-t) (var (gensym 'tmp)))
  (define (add-undef-vars v)(set! undef-vars (cons v undef-vars)))
  (define (new-var [t-ref NoType])
    (if (equal? t-ref NoType) 
	(let ((r1 
	       ;(gen-unknown-type)
	       (gensym 'new)
		  ))
	  (env-add-var r1) (add-undef-vars r1) r1)
	t-ref))
  (define (new-t [t-ref NoType]) 
    (vart (new-var t-ref)))
  (define (t-ref-var t-ref) (if (equal? t-ref NoType) (tmp-t) t-ref))

  ;(define (expand-t t) (expand-type t env))
  (define (expand-t t) (expand-type t env-ck))

  ;(define (typeup-ref v t) (let-values ([(r e) (type-type-ref-match-renew2 v t env #t)])(set! env e) r))
  ;(define (typeup v t)     (let-values ([(r e) (type-type-ref-match-renew2 v t env #f)])(set! env e) r))
 ;(define (typeup vt t)(add-ck-constraints ( =or vt t)) vt)
 (define (typeup vt t)(add-ck-constraints ( == vt t)) vt)
 ;(define (typeup-loose vt t)(add-ck-constraints ( ==loose vt t)) vt)
 ;(define (typeup-later vt t)(add-ck-constraints-later ( =or vt t)) vt)
    ;; (if (any/var? t)
    ;; 	(add-ck-problems ( =or  (vart v) t))	
 ;(define (typeup-ref vt t)(add-ck-constraints-later ( ==loose vt t)) vt)
 (define (typeup-ref vt t)(typeup vt t))


  ;; (define (var v) (let ((kv (assoc v env))) (if kv (cdr kv)  (typeup v (gen-unknown-type)))))

  (define (vart v);;var->type
    (let ((kv (assoc v env-ck)))
      (if kv (cdr kv) 
  	  ;(typeup v (gen-unknown-type))
	  (new-t v)
	  )))

  (define (var-set-E v E)
    ;(display (list 'var-set-E v E))(newline)
    (let* ([tv (vart v)][tE (inf-as-ref E (vart v))])
      (add-ck-constraints ( =or tv tE)) 
      ;(add-ck-constraints ( == tv tE)) 
      tE ))
  ;; (define (var-set-E-ref v E)
  ;;   (let* ([tv (vart v)][tE (inf-as-ref E (vart v))])
  ;;   ;(add-ck-constraints-later ( ==loose tv tE )) 
  ;;   (add-ck-constraints ( ==loose tv tE ))
  ;;   tE))

  ;; (define (var-set-E v E)
  ;;   (let ((vv (var-non-fix-type? v env) ))
  ;;     (if vv (typeup v (inf E))
  ;; 	  (typeup v (inf-as-ref E (vart v))))))

  (define (index-t-expr N)
    (cond 
       [(number? N) N]
       ;[(and (symbol? N) (number? (expand-t N)) )  (expand-t N)   ]
       [else 
	;(typeup (inf-as-ref N Int) Int) (new-t)
	(tmp-t)
	]
       ))
  (define-macro (inf-vec-like cont expr t-ref VectorType)
    (let (
	  (Vector ''vector)
	  (MakeVector ''make-vector)
  	  (VectorRef ''vector-ref)
  	  (VectorSet ''vector-set!)
  	  (VectorLength ''vector-length)
  	  (VectorMap ''vector-map )
	  )
      (when (equal? VectorType "list")
	    (set! Vector ''list)
  	    (set! MakeVector ''make-list)
  	    (set! VectorRef ''list-ref )
  	    (set! VectorSet ''list-set! )
  	    (set! VectorLength ''length)
	    (set! VectorMap ''map)
	    )
      ;(display (list 'inf-vec-like0 Vector MakeVector t-ref expr ))(newline)
  ; (define-macro (inf-vec-like cont expr t-ref Vector MakeVector VectorRef VectorSet VectorLength)
   `(let ([t-return (t-ref-var t-ref)])
      ;(display (list 'inf-vec-like ,Vector ,MakeVector ,t-ref ,expr ))(newline)
     (match 
     ,expr
     [`(,,Vector ,E ...)
      ;(display (list 'inf-vev-vec E ))(newline)	
      (let* ((es (map inf E))
	     ;(r	(if (list-all-equal? es)
		;    `(,,MakeVector ,(length es) ,(car es))
		 ;   `(,,Vector . ,es)))
	     )
	;(typeup-ref r t-ref)	    
	(if (list-all-equal? es)
	    (typeup `(,,MakeVector ,(length es) ,(car es)) t-return)
	    (typeup `(,,Vector . ,es) t-return))
	 ;;    (begin 
	 ;;      (add-ck-constraints
	 ;; ;; (conde 
	 ;; ;;   [
	 ;; ;;   (fresh (o n)
	 ;; ;; 	  (uniform-list-o-n es o n)
	 ;; ;; 	  ( == t-return  `(,,MakeVector ,n ,o)))
	 ;; ;;    ]
	 ;; ;;  [
	 ;;     ( ==  `(,,Vector . ,es) t-return)
	 ;;  ;;  ]
	 ;;  ;; )
	 ;;     )
	 ;;    t-return
	 ;;    )
	)
	;(display (list 'inf-vev-vec r ))(newline)	
	;(typeup-ref r t-ref)
	;(unless (equal? t-ref NoType) (typeup r t-ref))
	;r
	]
     [`(,,VectorLength ,X) ;;;;????/ not work list length???
      ;(display (list 'inf-vec-len X ,VectorLength ))(newline)
      (let ([x (inf X)])
      (add-ck-constraints
       ;; (membero (inf X) (list
       ;; 		    `(,,MakeVector ,(new-t) ,(new-t))
       ;; 		    `(,,Vector . ,(new-t))))
       (fresh (e n es)
	      (conde
	       [(== x `(,,MakeVector ,n ,e)) ]
	       [(== x `(,,Vector . ,es))]))
       ))
      Int]
     [`(,,MakeVector ,N ,V)
      ;(display (list 'inf-make-vec-non-num-n N V ))(newline)
      (typeup `(,,MakeVector ,(index-t-expr N) ,(inf V)) t-return)
      ]
     [`(,,VectorSet ,X ,N ,V)
      ;(display (list 'inf-vec-set X N V))(newline)
      (inf-as-ref `(,,VectorRef ,X ,N) (inf V))
      ;; (let* (
      ;; 	     (n (index-t-expr N))
      ;; 	     (v (inf V))
      ;; 	     (x (inf X)))
      ;; 	(if (number? n)
      ;; 	    (add-ck-constraints
      ;; 	     (fresh ( e m vs)
      ;; 	      (conde
      ;; 	       [(== x `(,,MakeVector ,m ,e)) (== e v) ]
      ;; 	       [(== x `(,,Vector . ,vs))
      ;; 		;(listo-ref vs n e)(=or e v)  
      ;; 	       ]
      ;; 	       )))
      ;; 	     (add-ck-constraints
      ;; 	      (fresh (e m vs) 
      ;; 	       (conde
      ;; 		[(== x `(,,MakeVector ,m ,e)) (== e v) ]
      ;; 		[(== x `(,,Vector . ,vs) )
      ;; 		       ;(conda [(varo vs) succeed] [(varnoto vs) (membero e vs)(== e v) ])
      ;; 		       ] 	     ;;;;(membero v vs) ;;;inf loop!!!
      ;; 	       ))))	)
	Void]
     [`(,,VectorRef ,X ,N)
      ;(display (list 'inf-vec-ref X N ))(newline)
      (let* (
	     (n (index-t-expr N))
	     (x (inf X))
	     ;(v (if (equal? t-ref NoType) (new-t) t-ref)) 
	     [v t-return]
	     )	

	(add-ck-constraints
	 (fresh (e m vs)
		(== x `(,,MakeVector ,m ,e)) (== e v)))

	;; (if (number? n)
	;;     (add-ck-constraints
	;;      (fresh (e m vs)
	;;       (conde
	;;        [(== x `(,,MakeVector ,m ,e)) (== e v) ]
	;;        [(== x `(,,Vector . ,vs))
	;; 	;(listo-ref vs n e)(=or e v)  
	;; 	])))
	;;      (add-ck-constraints
	;;       (fresh (e m vs)
	;;         (conde
	;;          [(== x `(,,MakeVector ,m ,e)) (== e v) ]
	;; 	 [(== x `(,,Vector . ,vs))
	;; 	       ;(conda [(varo vs) succeed] [(varnoto vs) (membero e vs)(=or e v) ])
	;; 	 ] 	     ;(membero v vs) ;;;inf loop!!!
	;; 	 ))) )
	v
	) 
      ]
     ;; [`(vector-map ,F ,X ...) ]
     [ _ 
       ;(display (list 'inf-vec-lasr ,expr ))(newline)
       (,cont ,expr ,t-ref)]
     )
     )
   )
  ) 

  (define (inf-base cont expr t-ref)
    ;(display (list 'inf-base expr)) (newline)
  (let ([t-return (t-ref-var t-ref)])
   (match
     expr
     ['true Bool]
     ['false Bool]
     [(? boolean?) Bool]
     [(? exact-integer?) Int]
     [(? double?) Double ]
     [(? pure-complex?) Complex]
     [(? pure-rational?) Rational ]
     [(? number?) Number]
     [(? string?) String]
     [(? char? e) Char ]
     [(quote (? symbol? )) Symbol]
     ;[(? constant? c) #()]




     [ (list (? op-float->float? ) X) (inf-as-ref X Double) Double]
     [ (list (? op-float->float? ) E ...) (for-each (curryr inf-as-ref Double) E )  Double]
     [`( ,(? op-num-num-bool? o ) ,E ...)
      ;(for-each (curryr inf-as-ref Number) E )
      (let (
	     [targs
	      (map (lambda (x) 
		     (let ([tx (inf x)])
		       ;(add-ck-constraints-later (membero tx number-type-order-list))
		       (add-ck-constraints (number-typeo tx))
		       ;; A disjunction of tx=Number and its negation is a
		       ;; tautology: it constrains nothing but doubles the
		       ;; search at every arithmetic site, so run* returned
		       ;; 2^k solutions for k sites.  number-typeo above is
		       ;; the real constraint.
		       tx))
		   E)]
	    )      
      Bool)
      ]

     [`(set! ,v ,E) (var-set-E v E) Void ]

     [`(define (,(? symbol? F) ,params ...) ,E ... ) 
      ;(for-each vart params) 
      (let ((r (inf `(begin . ,E))))
	;;;;(display (list 'inf-define F params r env))(newline)
	(add-return-type r)
	(typeup (vart F) `(lambda ,(map vart params) ,r))
	)
      Void]
     [`(define ,(? symbol? X) ,E) (var-set-E X E) Void ]
     ;[`(display ,X) (inf X) Void]
     ;['(newline) Void]
     ; ;[`(,(? scm2cpp-primitive? E0) . ,Es) (for-each inf Es) Void]
     ;; [_ (cont expr)]))
  ;; (define (inf-sub cont expr t-ref)
    ;; (match
     ;; expr
     [(? symbol? X)
      (let ([tX (vart expr)])
	(if (equal? t-ref NoType) 
	    tX 
	    ;(typeup-ref tX t-ref)
	    (typeup tX t-ref)
	    ))]

     ;; [`( ,(? op-num-num-num? o) . ,E) (most-general-number-type  (map (curryr inf-as-ref t-ref) E))]
     [(or `(remainder ,X ,Y)  `(quotient ,X ,Y)) 
      (typeup (inf X) Int) (typeup (inf Y) Int) Int]
     [`( ,(? op-num-num-num? o) . ,E)
      ;(when (equal? t-ref NoType)(set! t-ref Number)) 
      (let* (
	    ;(arg-types (map (lambda (x) (var-env->type (inf-as-ref x t-ref) env-ck)) E))
	     [tr
	      ;(new-t NoType) ;;debug
	      (t-ref-var t-ref) ;;no debug info 
		 ]
	     ;[tr (vart r)]
	     [targs
	      (map (lambda (x) (let ([tx (inf x)])
				 ;(display tx)(newline)
				 ;(add-ck-constraints (conde [succeed][(membero tx number-type-order-list)]))
				 ;(add-ck-constraints (conde [(varo tx)][(membero tx number-type-order-list)]))
				 ;(add-ck-constraints (conde [succeed][(=or tx Int)]));;bug of =or
				 ;(add-ck-constraints (conde [succeed][(== tx Int)]))
				 ;(add-ck-constraints (=/= tx Optional))
				 (add-ck-constraints (number-typeo tx))  
				 ;; The tautological disjunction removed here
				 ;; is the same one as in the comparison case.

				 ;(add-ck-constraints (== tx 1))
				 tx))
				 E)]
	    )
	;(display (list 'inf-op-num-num-num E targs ))(newline)

	;(most-general-number-type arg-types)
	;(most-general-type arg-types env-ck)
	;(add-ck-constraints       (=/= tr Optional ) )
	;(add-ck-constraints-later (most-general-number-type-list-o-ck targs tr))
	;(add-ck-constraints (=/= tr Optional))
	(add-ck-constraints (number-typeo tr))
	(add-ck-constraints (most-general-number-type-list-o-ck targs tr))
	;(add-ck-constraints (conde [(varo tr)][(membero tr number-type-order-list)]))
	

	;(add-ck-constraints (membero targs tr))
	;(add-ck-constraints (== (car targs) tr))
	tr
	)]

     ;; [`(begin ,E0 ,(? not-terminal-statement? E1))
     ;;  (let ([r1 (inf-as-ref E1 t-ref)]
     ;; 	    [r2 (inf-as-ref E0 t-ref)]
     ;; 	    )
     ;; 	(add-ck-constraints (conde [( == r1 t-return)][( == r2 t-return )]))        
     ;; 	t-return)]
     ;; [`(begin ,(? not-terminal-statement? E1))
     ;;  (let ([r1 (inf-as-ref E1 t-ref)]
     ;; 	    )
     ;; 	(add-ck-constraints (conde [( == Void t-return)][( == r1 t-return )]))        
     ;; 	t-return)]


     ;; [`(begin ,E0 (when ,E1 ,E2))
     ;;  (let ([r (inf-as-ref `(when ,E1 ,E2) t-ref)])
     ;; 	(add-ck-constraints (conde [( == Void t-return)][( == r t-return )]))        
     ;; 	t-return)]
     ;; [`(begin ,E0 (unless ,E1 ,E2)) 
     ;;  (let ([r (inf-as-ref `(unless ,E1 ,E2) t-ref)])
     ;; 	(add-ck-constraints (conde [( == Void t-return)][( == r t-return )]))        
     ;; 	t-return)]

     [`(begin ,E) (inf-as-ref E t-ref)]
     [`(begin ,E0 ,E ...)
      ;(display `(begin . ,E)) (newline) #()
      (inf E0)
      (inf-as-ref `(begin . ,E) t-ref)
      ]
     ['(begin ) Void]

     ;; [`(begin . ,E) 
     ;;  ;(display (list 'begin-inf E))(newline)
     ;;  (if (null? E) null
     ;; 	  (let ((e1 (drop-right E 1))
     ;; 		(e2 (last E)))
     ;; 	    ;(display (list 'begin2-inf e1 e2))(newline)
     ;; 	    (for-each inf e1)
     ;; 	    (inf-as-ref e2 t-ref)
     ;; 	   ))]

     [`(let ,(? symbol? v) ,bindings ,E ... )  ;;named let
      ;(display (list 'named-let-inf v bindings E))(newline)      
      (for-each (lambda (e) (var-set-E (car e) (cadr e))) bindings)
      (let* (
	     (r  (inf-as-ref `(begin . ,E) t-ref))
      	     (params (map car bindings))
	     )
	(add-return-type r)
      	(typeup `(lambda ,(map vart params) ,r) (vart v))
      	r
      	)
      ]
     [`(let ,bindings ,E ... )
      (for-each 
       (lambda (e)
	 (match 
	  (cadr e)
	  [`(lambda ,Params ,E0 ... )
	   ;(inf `(define (,(car e) ,@(Params)) . ,E0))
	   ;(display `(define ,(cons (car e) Params) . ,E0))(newline)
	   (inf `(define ,(cons (car e) Params) . ,E0))
	   ]
	  [_  (var-set-E (car e) (cadr e))])) 
       bindings)
      (inf-as-ref `(begin . ,E) t-ref)]
     [`(let* ,E ... ) (inf-as-ref `(let . ,E) t-ref)]
     [`(letrec ,E ... ) (inf-as-ref `(let . ,E) t-ref)]
     [`(letrec* ,E ... ) (inf-as-ref `(let . ,E) t-ref)]
     [`(do  ,bindings ,pred ,E ... )
      ;(display (list 'do-inf bindings pred E))(newline)
      (for-each (lambda (e) (var-set-E (car e) (cadr e)) (var-set-E (car e) (caddr e)) ) bindings)
      (inf (car pred))
      ;(display (list 'do-pred pred))(newline)
      (let ((r1 Void))
        (when ( >  (length pred) 1)
          (set! r1 (inf-as-ref (cadr pred) t-ref))) 
        (when (not (null? E)) (inf `(begin . ,E)))
        ;(inf-as-ref (cadr pred) t-ref)
        r1)
      ]
     [`(lambda ,params ,E ... ) (for-each vart params) 
      (if (equal? t-ref NoType)
	  (let ((r (inf `(begin . ,E))))
	    (inf `(begin . ,E))
	    `(lambda ,(map vart params) ,r))
	  (let ((r 
		 (match 
		  t-ref 
		  [`(lambda ,params1 ,r1) (inf-as-ref `(begin . ,E) r1) ]
		  [_ (inf `(begin . ,E))])))
	    (typeup-ref `(lambda ,(map vart params) ,r)  t-ref)))
      ]

     [`(not ,X) 
      ;(inf-as-ref X Bool)
      ;; The first branch of (conde [succeed][(== r Bool)]) already covers
      ;; every solution of the second, so the disjunction only duplicated
      ;; solutions.  The operand of not is unconstrained, as in Scheme.
      (inf X)
      Bool]

     [(or `(when ,E1 ,E2) `(if ,E1 ,E2))
      (let* ([rr t-return] )
	(let* ([ck-constraints0 ck-constraints-rigid]
	       [r1 (begin 
		     (set! ck-constraints-rigid '())
		     (inf E1)
		     (inf-as-ref E2 t-ref) )]
	       [ck-constraints1 
		(begin
		  ;;(add-ck-constraints (== rr r1))
		  (typeup r1 rr)
		  ck-constraints-rigid)]
	       [r2 (begin 
		     (set! ck-constraints-rigid '())
		     ;(add-ck-constraints ( == (inf-as-ref E1 Optional) Optional))
		     (let ([te1 (inf E1)])		       
		       ;(add-ck-constraints (conde [(== te1 Optional)] [(== te1 Bool)]))
		       (add-ck-constraints (== te1 Bool))
		       )
		     (typeup Void rr)
		     Void
		     )]
	     [ck-constraints2 
	      (begin
		;(add-ck-constraints (== rr r2))
		ck-constraints-rigid)]
	     )
	(set! 
	 ck-constraints-rigid
	 (append
	  (list (conde
		[(for-ckanren (reverse ck-constraints1))]
		[(for-ckanren (reverse ck-constraints2))]
		))
	  ck-constraints0
	      ))
	rr
	))
      ;; (inf-as-ref E1 Bool) 
      ;; (inf-as-ref E2 t-ref)
      ;; (when (equal? t-ref NoType)
      ;; 	  (inf-as-ref E2 Void))
      ;; (inf-as-ref E2 t-ref)
      ]
     [`(unless ,E1 ,E2)
      (let* ([rr t-return] )
	(let* ([ck-constraints0 ck-constraints-rigid]
	       [r1 (begin 
		     (set! ck-constraints-rigid '())
		     ;(add-ck-constraints ( == (inf-as-ref E1 Optional) Optional))
		     (let ([te1 (inf E1)])		       
		       ;(add-ck-constraints (conde [(== te1 Optional)] [(== te1 Bool)]))
		       (add-ck-constraints (== te1 Bool))
		       )
		     (inf-as-ref E2 t-ref) )]
	       [ck-constraints1 
		(begin
		  ;;(add-ck-constraints (== rr r1))
		  (typeup r1 rr)
		  ck-constraints-rigid)]
	       [r2 (begin 
		     (set! ck-constraints-rigid '())
		     (inf E1)
		     (typeup Void rr)
		     Void
		     )]
	     [ck-constraints2 
	      (begin
		;(add-ck-constraints (== rr r2))
		ck-constraints-rigid)]
	     )
	(set! 
	 ck-constraints-rigid
	 (append
	  (list (conde
		[(for-ckanren (reverse ck-constraints1))]
		[(for-ckanren (reverse ck-constraints2))]
		))
	  ck-constraints0
	      ))
	rr
	))
      ]

     [`(if ,E1 ,E2 ,E3)	
      ;(display (list 'if-inf E1 E2 E3))(newline)
      ;(add-ck-constraints (conde [succeed][(=or (inf E1) Optional)]))
      ;(add-ck-constraints (conde [succeed][(== (inf E1) Optional)]))
      ;(inf-as-ref E1 Bool)
      (let* (
	     [rr 
	      t-return
	      ;(t-ref-var t-ref)
	      ;(new-t NoType)
	      ;(new-t t-ref) ;;;debug
		 ]
	     [ck-constraints0 ck-constraints-rigid]
	     [r1 (begin 
		   (set! ck-constraints-rigid '())
		   (inf E1)
		   (inf-as-ref E2 t-ref)
		   ;(inf-as-ref E2 rr)		   
		   )]
	     [ck-constraints1 
	      (begin
		(add-ck-constraints (== rr r1))
		ck-constraints-rigid)
		]
	     [r2 (begin 
		   (set! ck-constraints-rigid '())
		   ;(add-ck-constraints ( == (inf E1) Optional))
		   (let ([te1 (inf E1)])		       		   
		     ;(add-ck-constraints (conda [(== te1 Bool)][(== te1 Optional)]))
		     ;(add-ck-constraints (conde [(== te1 Optional)][(== te1 Bool)]))
		     (add-ck-constraints (== te1 Bool))
		     )
		   (inf-as-ref E3 t-ref)
		   ;(inf-as-ref E3 rr)
		   )]
	     [ck-constraints2 
	      (begin
		(add-ck-constraints (== rr r2))
		ck-constraints-rigid)]
	     ;[rl (remove-duplicates (list r1 r2))]
	     )
	(set! 
	 ck-constraints-rigid
	 (append
	  (list (conde
		[(for-ckanren (reverse ck-constraints1))]
		[(for-ckanren (reverse ck-constraints2))]
		))
	  ck-constraints0
	      ))
	;(display t-ref)(newline)
	;(display rr)(newline)
	;(display rl)(newline)
	;;(typeup-ref r1 rr)
	;;(typeup-ref r2 rr) 
	;;(display (list 'type-if r1 r2  t-ref))(newline)
	;(more-general-type (inf-as-ref E2 t-ref) (inf-as-ref E3 t-ref) env)
        ;;rr        
	;(add-ck-constraints (membero rr rl))
	;(add-ck-constraints (== rr 1))
	rr
       ) 
      ]
     
     [`(cond (,p1  ,e1 ...) (else ,er ... ))
      ;(display (list 'cond-else-inf p1 e1 er))(newline)
	(match 
	 e1
	 [`(=> ,ea)
	  (inf-as-ref
	   `(if ,p1 (,ea ,p1) (begin . ,er)) t-ref)]
	 [_
	  (inf-as-ref 
	   `(if ,p1 (begin . ,e1) (begin . ,er) ) t-ref)]  )      
      ]
     [`(cond (,p1  ,e1 ...) )
      ;(display (list 'cond1-inf p1 e1))(newline)
	(match 
	 e1
	 [`(=> ,ea)
	  (inf-as-ref
	   `(when ,p1 (,ea ,p1) ) t-ref)]
	 [_
	  (inf-as-ref 
	   `(when ,p1 (begin . ,e1) ) t-ref)])
      ]

     [`(cond (,P  ,E ...) ... )      
      ;(display (list 'cond-inf (map cons P E)))(newline)
      (let ([p1 (car P)][e1 (car E)][pr (cdr P)][er (cdr E)])
      ;(lambda (p e0 pr er t-ref)
	(match 
	 e1
	 [`(=> ,ea)
	  (inf-as-ref
	   `(if ,p1 (,ea ,p1) (cond . ,(map cons pr er)) ) t-ref)]
	 [_
	  (inf-as-ref 
	   `(if ,p1 (begin . ,e1) (cond . ,(map cons pr er)) ) t-ref)] 	 ))
      ;; (inf-as-ref 
      ;;  `(if ,(car P) (begin . ,(car E)) (cond . ,(map cons (cdr P) (cdr E))) ) t-ref)
      ]

     ;; [`(cond ,E ...)
     ;;  (let ((clauses (drop-right E 1))(last-clause (last E)))
     ;;    ;;(display (list 'cond-inf E last-clause ))(newline)
     ;;    (let* ((rl (match last-clause
     ;;                [`(else ,E1 ... ) (inf-as-ref `(begin . ,E1) t-ref)] 
     ;;                [ _  (if (equal? t-ref NoType)
     ;; 			     (inf-as-ref `(begin . ,last-clause) Void)
     ;; 			     (inf-as-ref `(begin . ,last-clause) t-ref))]))
     ;;          (rm (map (lambda (x) (inf-as-ref `(begin . ,x) t-ref)) clauses ))
     ;; 	      (rr (foldl typeup-ref rl rm))
     ;; 	      )
     ;; 	;;(most-general-type	 (cons rl rm))))   
     ;; 	  rr))
     ;;  ]
     [`(case ,E1 ,E ...)  (display (list 'case-alpha E))(newline)
      ;;(inf-as-ref E1 Bool)
      (let* ((rs
	     ;; (most-general-type
	     (map (lambda (x) ;; (display x)(newline)
		    (match 
		     (car x)
		     ['else  'else] 
		     [_ (map inf (car x))]) 
		    (inf-as-ref `(begin . ,(cdr x)) t-ref) ) E ))
	    (rr (foldl typeup-ref (car rs) (cdr rs))))
	rr
	)
	]
     [`(display ,X) (inf X) Void]
     [`(display ,X ,P) (inf X) (inf P OStream) Void]
     [`(newline )  Void]
     [`(newline ,P)(inf P OStream) Void]
     ;;[`(car ,X) (let ((r (inf X))) (match r [`(list ,(? pair? Y))  ]   ) ]

     [`(apply . ( ,rator . ,rand))
      (inf-as-ref `(,rator . ,rand) t-ref)]
     
     ;; [`(length ,X)
     ;;  (add-ck-constraints-later 
     ;;   (membero (inf X) (list
     ;; 		    `(make-list ,(new-t) ,(new-t))
     ;; 		    `(list . ,(new-t)))))
     ;;  Int]

     [ _ (cont expr t-ref) 
      ;(list 'unknown_expression expr)
      ]
     )))
  (define (inf-last expr t-ref)
    ;(display (list 'inf-last t-ref expr)) (newline)
    (let ([t-return (t-ref-var t-ref)])
    (match 
     expr
     [`(,(? scheme-primitive? E0) . ,Es) (if (equal? t-ref NoType)(new-t)t-ref) ];;dummy-type
     
      ;; ;;app
     [ `(,(? symbol? rator) . ,rand)
       (let ([trand (map inf rand)]
	     [trator (inf rator)]
	     ;[tret (if (equal? t-ref NoType)(new-t)t-ref)]
	     [tret t-return]
	     )
	 (typeup trator `(lambda ,trand ,tret) ) tret)]

      ;; ;; ;;app nest
      ;; [ `((,(? symbol? rator) . ,rand1) . ,rand2) 
      ;;  (let ([targs (map inf Es))

      ;;  (fresh (trand1 trand2 tdummy)
      ;; 	(== tdummy Int)

      ;; 	(!-l `(lambda ,rand2 0) `(lambda ,trand2 ,tdummy) )
      ;; 	(!-l `(,rator . ,rand1) `(lambda ,trand2 ,t))
      ;; 	)]


     [`(,E0 . ,Es)
      (let* ((et (expand-t (inf E0))))
	;(display (list 'fnc-call-inf-ref E0 Es et)) (newline)      
	(match 
	 et
	 [`(lambda ,P ,R )
	  ;(display (list 'fnc-call1-inf-ref1 E0 Es P R)) (newline)      
	  (last `(lambda 
		     ,(map (lambda (p pr) 
			     (typeup p (inf pr))
			     ) P Es)
		   ,(typeup-ref R t-ref)))]
	 [ _ 	
	   (let* ((r (new-t t-ref))
                  (r1 (inf-as-ref E0 `(lambda ,(map inf Es) ,r)))
                  ;(r2 (inf E0))
                  ;(r3 (var E0)) 
                  )
             ;(display (list 'fnc-call-inf-ref2 E0 r r1 r2 r3)) (newline)      
              ;(last r3)
	     r
	      ) ]))
      ]
     [_ ;;(cont expr t-ref) 
      (error "unknown-expression in aplha" expr)
      (list 'unknown_expression expr)
      ])))
  (define (inf-as-ref expr1 [t-ref NoType] )
     ;(display (list 'inf-as-ref t-ref expr1 env))(newline)
    (inf-base
     (lambda (expr t-ref) 
       (inf-vec-like 
	(lambda (expr t-ref)
	  (inf-vec-like
	   inf-last
	   expr t-ref 
	   "list"
	   ;'list
	   ;'make-list 'list-ref 'list-set! 'length
	   ))
	expr t-ref 
	"vector"
	;'vector
	;'make-vector 'vector-ref 'vector-set! 'vector-length
	))	
     expr1 t-ref))	 
  (define (inf expr1) (inf-as-ref expr1 NoType))
    
  (display 'derive-type)(newline)

  (display expr-input)(newline)

  ;(display (list function-return-type-list (cons FunctionReturns function-return-type-list)))(newline) 

  ;(display (list env-ck1 env-ck2 env-union env-union-ck-var env-union-ck env-ck))(newline) 
  
  (let* ([r (inf-as-ref 
	     ;expr
	     expr-input 
	     NoType)
	 ;(use-inf-def expr)
	 ]
	 [ ret-env-type-ck-result 
	   (begin
	     ;(lstack-push! (cons FunctionReturns (cons 'list function-return-type-list)) env-ck)
	     (lstack-push! (cons FunctionReturns function-return-type-list) env-ck)
	     (run* (q)
		 (fresh (e t)
			(== e env-ck)
			(== t r)
			(for-ckanren (reverse ck-constraints-rigid))
			;(for-ckanren ck-constraints-rigid)
			(for-ckanren (reverse ck-constraints-later))
			;(!-g e expr t)
			(conso t e q))))
	   ]
	 ;[ret-ck1     (caar ret-env-type-ck-result)]
	 ;[env-ck1     (cdar ret-env-type-ck-result)]
	 )

    ;; (list 
    ;;  env-ck1    
    ;;  env-ck2 env-union
    ;;  env-union-ck-var
    ;;  env-union-ck
    ;;  env-ck
    ;;  ret-env-type-ck-result
    ;;  )

    ;(display 'derive-type)(newline)
    ;(display ret-env-type-ck-result)(newline)
    (display (length ret-env-type-ck-result))(newline)

    ;ret-env-type-ck-result
    (let*-values
	(
	 [(
	   env-union
	   ret-union 	   
	   unknown-typed-list-total
	   )
	  (type-ret-env-ck-list->union-env--unon-ret--unknown-typed-list ret-env-type-ck-result)
	  ]
	 )

    ;; (let* 
    ;; 	(	
    ;; 	 [unknown-typed-list-total '()]
    ;; 	 ;[undef-function-return-type-alist '()]
    ;; 	 [ret-env-match-list
    ;; 	 (map
    ;; 	  (lambda (ret-env-ck)
    ;; 	    (let* (
    ;; 		 [ret-ck (car ret-env-ck)]
    ;; 		 [env-ck (cdr ret-env-ck)]
    ;; 	  	 [unknown-typed-list-ck
    ;; 		  (type-env-ck->unknown-type-list env-ck)]
    ;; 		 [untype-varname-alist
    ;; 		  (type-env-unknown-type-list->untype-varname-alist env-ck unknown-typed-list-ck)]
    ;; 		 [unknown-typed-list (append unknown-typed-list-ck (map cdr untype-varname-alist))]
    ;; 		 [env (cl:sublis untype-varname-alist  env-ck)]
    ;; 		 [ret (cl:sublis untype-varname-alist  ret-ck)]
    ;; 		 )
    ;; 	      ;(set! (append unknown-typed-list-ck (map cdr untype-varname-alist)))
    ;; 	      (set! unknown-typed-list-total (remove-duplicates (append unknown-typed-list unknown-typed-list-total)))
    ;; 	      ;(display untype-varname-alist)(newline)
    ;; 	      (cons ret env)))
    ;; 	  ;(remove-duplicates            ret-env-type-ck-result)
    ;; 	   (refine-ck-conditional-result ret-env-type-ck-result)
    ;; 	  )
    ;; 	 ]
    ;; 	 [var-list 
    ;; 	  (foldl
    ;; 	   (lambda (re lst)
    ;; 	     (lset-union equal?
    ;; 	 		 (map car (cdr re))
    ;; 	 		 lst))
    ;; 	   '()
    ;; 	   ret-env-match-list
    ;; 	   )
    ;; 	  ]
    ;; 	 [env-union
    ;; 	  (map
    ;; 	   (lambda (x)	    
    ;; 	     (cons 
    ;; 	      x 
    ;; 	      (type-list->union
    ;; 	       (map
    ;; 		(lambda (re)
    ;; 		  (let ([kv (assoc x (cdr re))])
    ;; 		    (if kv (cdr kv) (list Union))))
    ;; 		ret-env-match-list))))
    ;; 	   var-list)
    ;; 	     ]
    ;; 	 [ret-union 
    ;; 	  (type-list->union
    ;; 	   (map 
    ;; 	    car
    ;; 	    ret-env-match-list))]	 	 
    ;; 	 )


      (set! number-typed-list
	  (map car (filter
	   (lambda (kv)
	     ;(display kv)(newline)
	     (let ([k (car kv)][v (cdr kv)])
	       ;(display (list k v))(newline)
	       (if (list? v)
		   (if
		    (equal? 
		     (lset-difference equal? v number-type-order-list)
		     (list Union k))
		    true
		    false)
		   false)
	       ))
	   env-union) )
	  ;'()
	  )
      (set! any-typed-list (lset-difference equal? unknown-typed-list-total number-typed-list)  )

      ;;;;;;; number-union-type->any 
      ;; (set! env-union
      ;; 	    (map 
      ;; 	     (lambda (kv)
      ;; 	      ;(display kv)(newline)
      ;; 	       (let ([k (car kv)][v (cdr kv)])
      ;; 		 (if (member k number-typed-list) 
      ;; 		     (cons k k) kv)))
      ;; 	      env-union))


      (set! ret-union (refine-union-type-sexp ret-union))
      (set! env-union (refine-union-type-sexp env-union))
      
      ;; (let optinal->bool ([e env-union])
      ;; 	(pair? 
      ;; 	(match e
      ;; 	  [`(U
      ;; 	(if (lset= equal?  e (list Union ) 
      ;; 	) 
      ;; ;(set! env-union
      ;; ;; (map-tree 
      ;; ;;  (
      ;; ;;  env-union
	     
	   

      ;ret-env-type-ck-result	  		 
      ;(list number-typed-list any-typed-list ret-env-match-list var-list env-union ret-env-type-ck-result)
      ;; (list number-typed-list any-typed-list  env-union ret-union unknown-typed-list-total
      ;; 	  (refine-ck-conditional-result ret-env-type-ck-result) 
      ;; 	    ;ret-env-type-ck-result
      ;; 	    )
      ;(list number-typed-list any-typed-list  env-union ret-union unknown-typed-list-total)

      ;(list ret-env-match-list var-list env-union ret-env-type-ck-result)
      ;(cons  ret-union env-union)


      (values env-union ret-union unknown-typed-list-total)

      )

    ;;;env-ck1 
    ;;;ret-ck1 
    ;(env-ret-ck-result->env-ret-unknown-typed-list-values env-ck1 ret-ck1)
    )
  )

;;(derive-type '3 `((x . x) (y . y) (z . ,Double) ) )
;; (derive-type 'z `((x . x) (y . y) (z . ,Double) ) )
;; (derive-type 'y `((x . x) (y . x) (z . ,Double) ) )

;; (derive-type '(car y) `((x . x) (y . x) (z . ,Double) ) )
;; (derive-type '(+ x y) `((x . x) (y . x) (z . ,Double) ) )
;; (derive-type '(+ x y) `((x . x) (y . y) (z . ,Double) ) )
;; (derive-type '(+ x z) `((x . x) (y . y) (z . ,Double) ) )
;; ;; ;(newline)




(define (infer-type-from-org-expr expr-org)
  (define-values (expr-alpha env-alpha env-free) 
    (alpha-conv 
     (pre-alpha-expr-mod
      expr-org)))
  (define env-alpha-inv (envinvert env-alpha))
  (define env-free-inv  (envinvert env-free))
  ;; (define env-init-type 
  ;;   (cl:sublis
  ;;    `((int . ,Int) (float . ,Float) (double . ,Double) )
  ;;    (alpha-free->type-env env-alpha-inv env-free-inv)))

  ;(display (list 'env-init-type env-init-type)) (newline)
  ;(display (cl:sublis  `((int . ,Int)) env-init-type) )(newline)
  (define env-type
    (cl:sublis
     `((int . ,Int) (float . ,Float) (double . ,Double) )
     (update-init-env-init-unknown-type-list
      (alpha-free-exp->init-type-full-env  env-alpha-inv env-free-inv expr-alpha))))
  ;display (list 'env-type env-type expr-alpha)) (newline)

  ;(display (list expr-alpha env-type  unknown-typed-list)) (newline)
  ;(display (list expr-alpha env-type  unknown-type-list)) (newline)
  ;; (display env-alpha-inv)
  ;; (display env-free-inv)
  ;; (display env-init-type )
  ;; (display env-type) (newline) 
  (let-values ([(dpends-ret 
		 depends mutables refereds 
		 funcalls lambdas 
		 function-return-not-use
		 return-lambdas
		 local-lambdas)
		(depend-analysis expr-alpha)])
  (let*-values (
		[(env1 
		  r1 unknown-typed-list-local1)
  		;; Hindley-Milner by default; the relational implementation
		;; remains available through SCM2CPP_RELATIONAL=1.
		(if (getenv "SCM2CPP_RELATIONAL")
		    (derive-type expr-alpha env-type)
		    (derive-type-hm expr-alpha env-type))]
		)
	      (values env1 r1 unknown-typed-list-local1
		      expr-alpha env-alpha-inv env-free-inv) 

	;;       (newline)(display env1) (newline)
	;;       (let loop ([env2 env1])
	;; 	(let-values (
	;; 	   [(env 
	;; 	     r unknown-typed-list-local)
	;; 	    (derive-type expr-alpha 
	;; 			 env2
	;; 			 )]
	;; 	   )
	;; ;(display (list 'env-diff (lset-difference equal? env1 env) (lset-difference equal? env env1)))(newline)
	;; 	  (display (list 'env-diff1 (lset-difference equal? env2 env) ))(newline)
	;; 	  (display (list 'env-diff2 (lset-difference equal? env env2) ))(newline)
	;; 	  (if ( >  (length (flatten env1))
	;; 		   (length (flatten env)))
	;; 	      (begin
	      
	;; 		(loop env)
	;; 		)
	;;     ;(display (list 'env1 env1 r1)) (newline)    
	;; 	      (begin 
	;; 		(set!unknown-type-list unknown-typed-list-local)
	;; 		(values env r unknown-typed-list-local expr-alpha env-alpha-inv env-free-inv) 
	;; 		))
	;; 	  ))
    )

  ;; (var-declared-type? 'f-int env-alpha-inv env-free-inv)
  )
)



;unknown-typed-list
;unknown-type-list

;; ;;debug
;; (define (type-inference expr)
;;   (let*-values ([(ex ev fv) 
;; 		 (alpha-conv 
;; 		  expr)
;; 		 ]
;; 		;; [(dpends-ret 
;; 		;;   depends mutables refereds 
;; 		;;   funcalls lambdas 
;; 		;;   function-return-not-use
;; 		;;   return-lambdas
;; 		;;   local-lambdas)
;; 		;; (depend-analysis ex)]
;; 		)
;;     ;(display function-return-not-use)(newline)
;;     ;(display ex)(newline)
;;    ;(display ev)(newline)
;;    ;(display fv)(newline)    
;;     (let* (
;; 	   [evs (append ev fv) ]
;; 	   ;[evs (append ev fv `( (,Flags . ,Flags))) ]
;; 	   [envt (map (lambda (xv) (cons (cdr xv) (var (cdr xv) ))) evs )]
;; 	  ;; [ret-g 
;; 	  ;;  (run* (q)
;; 	  ;; 	 (fresh (e t)(== e envt)(!-g e ex t)(conso t e q))
;; 	  ;; 	 ;(assign-env-void-return-ck envt function-return-not-use) 
;; 	  ;; 	 )]
;; 	  )
;;       (expr-type-var->type ex envt)
;;       ;; (map
;;       ;;  (lambda (r)
;;       ;; 	 (assign-env-void-return (cdr r) function-return-not-use)
;;       ;; 	 )
;;       ;; ;(display evs)(newline)    
;;       ;; ret-g)
;;       )))
;; ; (refine-ck-conditional-result

;;       ;(display envt)(newline)
;;       ;(display ret-g)(newline)

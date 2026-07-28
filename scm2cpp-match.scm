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
    (abs . "abs")    
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
  (define pre-cfun "")
  (define post-cfun "")
  (define (add-pre-cfun str) (set! pre-cfun (str-a pre-cfun str)))
  (define (add-pre-cfun-semi str) (add-pre-cfun (format "~a;~n" str))) 
  (define current-template-vars '())  
  (define current-template-types '())  
  (define c-includes '())
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
  
  (define (ctype v)
    (if (non-fix-type? v)
	(var-name-to-template-type-name (cname (vtype v)))
	(type->ctype (vtype v))
	))
  (define (cppuniontype E)
    (c-includes-add "\"scm2cpp.hpp\"" )
    (format 
     ;"typename scm2cpp::variant_shrink< ~a  >::type "
     "typename scm2cpp::make_variant_shrink_over< boost::mpl::vector< ~a > >::type "
     (string-join (map cpptype E) ",")	))
  (define (cpptype-arg t)
    (cond 
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (var-name-to-template-type-name (cname v)))  ]
     [else (cpptype t) ]))
  (define (cpptype t);;type->cpptype
    ;(display (list "cpptype0 " t))(newline)
    (cond
     ;[(symbol? t) (ctype t)]
     [(member t unknown-type-list) (var-name-to-template-type-name (cname t))]
     [(optional-union-type? t) => (lambda (x) (format "boost::optional<~a>" (cpptype x)  ))]
     [(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (var-name-to-template-type-name (cname v)))  ]
     [(symbol? t)  (type->ctype t)]
      
     ;[(type-unknown->number-any-union-type? t unknown-type-list) => (lambda (v) (var-name-to-template-type-name (cname v)))  ]
     [else
      (match 
       t
     ;[(? symbol? X)  (ctype X)]
       [`(,(? union-symbol? U) ,E ...) 
	;(if  (pair? (lset-intersection eq? E unknown-type-list))
	(let* ([var-types (lset-intersection eq? E unknown-type-list)]
	       [E-subtrected
	       (lset-difference equal? E				
				(apply lset-union (cons eq? (map vtype var-types))))])
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
     [`(list ,params ... )
      (if (list-all-equal? params)
	  (begin
	    (c-includes-add "<vector>")
	    (format "std::vector< ~a >" (cpptype (car params))))
	  (begin 
	    (c-includes-add "<boost/fusion/include/list.hpp>")
	    (format "boost::fusion::list< ~a >" (string-join (map cpptype params) ","))))
      ]
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
	 [(member e t) (var-name-to-template-type-name (cname e)) ]
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
       [(member e t)(cpptype-arg t)]
       [else (cpptype t)];;(expand-type (expr->type e) env-type-local)
       )))
  (define (svars->cargs vars ref-flag)
    ;(display (list "svars->cargs " vars ref-flag))(newline)
    (let* ((cvars (map cname vars))
	   (ctypes (map sarg->cpptype vars))
	   (ctop (if ref-flag " & " "")))
      (string-join (map (lambda (t v) (format " ~a ~a ~a " t ctop v)) ctypes  cvars ) " , ")))
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

    (display (list 'svars->ctemplatedef vars))(newline)

    (if (null? vars) ""
	(format "template< ~a > "
		(str-j
		 (map (lambda (x) (format "typename ~a" 
					  ;(sexp->cpptype x)
					  (var-name-to-template-type-name (cname x))
					  )) 	
		      vars
		      ;(vars-typeenv-unknown->unknown-types vars env-type-local unknown-type-list)
		      ) ","))))
  (define (clambda expr lambda-name lambda-obj-name free-ref-flag)
    (let-values ([(type1 lambda-type1 unk1) (derive-type expr env-type-local)])
      (let* ((freevars (sexp-free-var expr )) 
	     (lambda-ret-type (last lambda-type1)) 
	     ( cdef-lambda-obj "")
	     ( c-lambda-name (cname lambda-name)) 
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
		    (let* ([E0-cstr1 
			    (if (null? e0-f-type)
				(str-a E0-cstr "<" (str-j E0-type-a-specialization ",") ">")
				(str-a E0-cstr "<" (str-j E0-type-f-specialization ",") ">().operator()<" (str-j E0-type-a-specialization ",") ">"))]
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
     [(? boolean? X) (if (equal? X #t) "true" "false" ) ]
     [(? number? X) (number->string X) ]
     [(? string? X) (string-append "\"" X  "\"") ]
     [(? char? X)   (string-append "'" (string expr)  "'") ]   

     [(? symbol? X)  (cname X)]
      ;; (if (eq? t-ref NoType)  (cname X)
      ;; 	  (let ([tx (vtype X)])	
      ;; 	    (if (equal? t-ref tx) (cname X)
      ;; 		(str-a (cpptyp t-ref) "(" (cname X) ")"))))]


     [`(quotient ,N ,M) (format "~a / ~a"  (cexp-num  N) (cexp-num  M))  ]
     [`(atan ,X ,Y) (c-includes-add "<math.h>") (format "atan2(~a , ~a)"  (cexp-num  X) (cexp-num Y))  ]
     [`(abs ,X) (format "abs(~a)" (cexp-num  X)) ]
     [`(max ,X ,Y) (format "std::max( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [`(min ,X ,Y) (format "std::min( ~a , ~a )" (cexp-num X) (cexp-num Y)) ]
     [ (list (? op-float->float? Op) X) (c-includes-add "<math.h>") (format "~a(~a)" Op (cexp X ))  ]
     [`(not ,X) (format "!(~a)" (cexp X)) ]
     [`(zero? ,X) (format "(~a == 0 )" (cexp-num  X)) ]
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
      (c-includes-adds (list "<boost/array.hpp>"  "<boost/assign.hpp>"))      
      ;;(format "boost::array<~a,~a> ~a=boost::assign::list_of<~a>().repeat(~a,~a)"  (sexp->cpptype V) N (cexp X) (sexp->cpptype V) N (cexp V) )
      (format "boost::array<~a,~a> ~a=boost::assign::list_of(~a).repeat(~a,~a)"  
	      (sexp->cpptype V) N (cexp X)   
	      (cexp V) (- N 1) (cexp V) )
      ]
     [(or 
       `(define ,(? symbol? X) (make-vector ,N ,V))
       `(define ,(? symbol? X) (make-list ,N ,V)))
      (c-includes-add "<vector>")
      (format "std::vector<~a> ~a(~a,~a)" (sexp->cpptype V) (cexp X) N (cexp V))]
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
       (str-a
	(apply str-a (map cstat-semi (drop-right E 1)))
       ;; (cexp-ret (last E))
	(cterm-stat (last E))
       ;)
       )]
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
      (let* ((cvarsinit (map (lambda (e) (cexp `(define ,(car e) ,(cadr e)))) bindings))
	    (cvarsnext (map (lambda (e) (cexp `(set! ,(car e) ,(caddr e)))) bindings))
	    (cend (str-a "!(" (cexp (car pred)) ")"))
	    (cret (if ( >  (length pred) 1)
		      (cexp (cadr pred)) ""))
	    (cb (if (null? E) ""
		    (begin-inc-dev-lv
		     (str-a "{" (cstat-semi `(begin . ,E)) "}")))))
	(if (or (equal? cterm-stat cstat-semi) ( <  (length pred) 2))
	    (str-a (format "for( ~a ; ~a ; ~a )" (str-j cvarsinit ",") cend (str-j cvarsnext ","))  cb)
	    (str-a 
	     (format "for( ~a ;; ~a )" (str-j cvarsinit ",") (str-j cvarsnext ","))
	     (format "if( ~a ){ ~a }else{ ~a }  " (cexp (car pred)) (cterm-stat (cadr pred)) (begin-inc-dev-lv (cstat-semi `(begin . ,E)))))))]
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
     [`(begin ,E ...) (apply string-append (map cstat-semi E) )]
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
	  (let* ((func-def-cstr (format "~a \n ~a(~a)"  (cpptype lambda-ret-type) (cname F) (svars->cargs params #false)))
		 (cfunstr	    
		  (format 
		   "\n ~a \n ~a \n {~a}" 
		   ;(svars->ctemplatedef current-template-vars) 
		   (types->ctemplatedef current-template-types) 
		   func-def-cstr 
		   (begin
		     (inc-lv)
		     (cstat-ret (cons 'begin E)) ;;func body
		     )
		   ))
		 (cfunstr2 (str-a pre-cfun cfunstr)))
	    ;(display (list "cdeffun3"  current-template-vars))(newline)
	    (dec-lv)
	    (when (null?  current-template-vars) (fprintf port-h "~a;~n" func-def-cstr))
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
  
  (map 
   cdefs (cdr expr-alpha))

  ;(string-append 
  (apply string-append 
	 (map (lambda (x) 
		(list->string (append (string->list "#include" ) '(#\tab) (string->list  x ) '(#\newline))))  
	      c-includes)
	 )
           
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
  (begin 
         ;(with-output-to-file "/tmp/cpp-code-indented.cpp" 
	 ;  (display cppcode-str)
         ;    #:exists 'replace )
    (display-to-file cppcode-str "/tmp/cpp-code-indented.cpp" #:exists 'replace)
    (port->string (car (process    (format  "astyle /tmp/cpp-code-indented.cpp" ))))
    (file->string "/tmp/cpp-code-indented.cpp" )
    ))

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
	 (call-with-input-string 
	  (string-append 
	   "(begin "
	   ;;scmcodestr
	   ;;scmcode-pre-expand-macro-str	   
	   (scheme-code-string-macro-expand scmcode-pre-expand-macro-str)
	  ")")
	  (lambda (p) (read p)))))
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








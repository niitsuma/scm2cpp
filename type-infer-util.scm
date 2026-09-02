#lang scheme

(provide

 double?
 pure-complex?
 pure-rational?

 unknown-type-list
 set!unknown-type-list
 init-unknown-type-list
 add-unknown-type
 remove-unknown-type
 gen-unknown-type
 gen-unknown-type-var
 unknown-type?
 assing-unknown-type->env 
 update-init-env-unknown-type-list
 update-init-env-init-unknown-type-list

 ;number-type-base-name-order-list
 ;number-type-order-list
 number-type-order-alist
 number-type?
 general-number-type>?
 more-general-number-type
 most-general-number-type 
 special-number-type>?
 more-special-number-type
 most-special-number-type 

 more-shrink-union-than?

 op-float->float?
 ;op-num-num-num
 op-num-num-num? 
 ;op-num-num-bool
 op-num-num-bool? 
 ;op-str-str

 scm2cpp-primitives 
 scm2cpp-primitive?

 ;type-symbol-alist
 ;symbol-type-alist 
 ;type-symbol
 ;Bool Int Float Double Number Char String Symbol
 ;Port Unknown Union NoType ExpandType TypeMatchFail Sexpr
 rigid-types 
 rigid-type? 

 var-non-fix-type?
 var-env-unknown->non-fix-type?
 var-env->direct-type
 var-env->type 
 expand-type

 type->ctype

 var-declared-type?
 var-alpha-free-type->type

 alpha-free-exp->init-type-full-env
 reduce-unknown-type



 ;union-symbol?
 ;number-symbol?
 

 ;number-typeo

 union-types-difference-correspond 

 type-env-match->type-env-rel-var-alist
 type-env-match->type-env-rel-var
 
 type-env->env-union-env-values
 type-env-match->type-env-rel-var--constraints--rel-var-alist
 type-env-match->type-env-rel-var-constraints

 type-env-rel->unknown-type-list
 type-env-rel->untype-varname-alist 
 
 type-env-unknown-type-list->untype-varname-alist

 type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list 

 type-env-rel->type-env-match
 env-ret-rel-result->env-ret-unknown-type-list-values

 more-general-number-type-rel
 most-general-number-type-list-o-rel


 type-type->union
 types->union
 type-list->union


 type-unknown->number-any-union-type?
 make-number-any-union-type?

 optional-union-type?


 vars-typeenv-unknown->unknown-types

 env-type-match-partial-specialization
)



(require "alist-util.scm")
(require "list-util.scm")


(require "alpha-conv.scm")
(require "type-symbols.scm")

(require "type-rel-util.scm")

(require "schlep-name.scm")

;(require rkanren)
(require (only-in rkanren
                    var var?
		    conda conde 
		    == 
		    =/= 
		    ;fail
		    ;never-pairo
		    ;pairo
		    run*
		    membero
		    ))


(require "rel-util.scm")

(require "onlisp.scm")
(require "cl-util.scm")


;(require srfi/1)
(require (only-in srfi/1
	 lset-difference	 
	 lset-intersection
	 lset=
	 lset-union
	 lset-adjoin
	 fold
	 ))

(require (planet "amb.scm" ("wmfarr" "amb.plt" 1 0)))

(define (double? x)(and (number? x) (not (exact-integer? x)) (flonum? x)))
(define (pure-complex? x)(and (number? x) (not (real? x))))
(define (pure-rational? x)(and (number? x) (not (exact-integer? x)) (not (double? x)) (not (pure-complex? x ))))
;(define (not-int? x)(not (exact-integer? x)))




(define unknown-type-list '())
(define (set!unknown-type-list v) (set!  unknown-type-list v))
(define (init-unknown-type-list ) (set!  unknown-type-list '()))
;(define unknown-type (gensym 'Unknown-Type));
(define (add-unknown-type t)
  (set! unknown-type-list 
	(lset-union equal? (list t) unknown-type-list)))
(define (remove-unknown-type t)
  (set! unknown-type-list 
	(lset-difference equal? unknown-type-list (list t))))
(define (gen-unknown-type) 
  (let ((t (gensym 'Unknown-Type)))
    (set! unknown-type-list 
	  (cons t unknown-type-list)) t))
(define (gen-unknown-type-var v) 
  (let ((t (gensym v))) (set! unknown-type-list (cons t unknown-type-list)) t))
(define (unknown-type? t [unknown-typed-list unknown-type-list]) (if (member t unknown-typed-list) #t #f))
(define (assing-unknown-type->env t v env)(remove-unknown-type t) (alist-cons-update t v env))
(define (update-init-env-unknown-type-list env)
  (map
   (lambda (kv) 
     (let ((k (car kv))
	   (v (cdr kv)))
       (when (equal? k v) 
	     (add-unknown-type k))
       kv
     )) 
   env))
(define (update-init-env-init-unknown-type-list env)
  (init-unknown-type-list ) 
  (update-init-env-unknown-type-list env))


;(define number-type-base-name-order-list '(bool int float double complex number))
(define (number-type? t) (member t number-type-order-list))
(define (special-number-type>?  t1 t2)
   (> (length (member t1 number-type-order-list) )
      (length (member t2 number-type-order-list) )))
(define (more-special-number-type t1 t2 ) (if (special-number-type>? t1 t2) t1 t2))

;; (special-number-type>? Double Int )
;; (more-special-number-type  Double Complex )
;;(more-special-number-type  'int 'double )
(define (general-number-type>?  t1 t2)
  (let ((tt1 (member t1 number-type-order-list)) 
	(tt2 (member t2 number-type-order-list)))
    (if (and tt1 tt2)
	(< (length tt1 )
	   (length tt2 )) 
	(if tt1 #t #f))))  
(define (more-general-number-type t1 t2 )
  (let ((tt1 (member t1 number-type-order-list)) 
	(tt2 (member t2 number-type-order-list)))
    (if (and tt1 tt2)
	(if ( < (length tt1 )
	       (length tt2 ) ) t1 t2 )
	(if tt1 t1 t2))))
;; (general-number-type>?  'double 'bool )
;; (more-general-number-type  Bool Int )
;; (more-general-number-type  'float 'int )
;; (more-special-number-type>?  'int 'double )
(define (most-general-number-type lst)
  (fold more-general-number-type (car lst ) (cdr lst)))
;; (most-general-number-type '(int int float))
;; (most-general-number-type '(int int float aaaa))
(define (most-special-number-type lst)
  (fold more-special-number-type (car lst ) (cdr lst)))
;; (most-special-number-type '(int int float))


;(define op-num-num-num  '(+ - * / remainder))
(define (op-float->float? x) (member x op-float->float))  
(define (op-num-num-num? x) (member x op-num-num-num))
;(define op-num-num-bool '( =  >  <  <= >=   ))
(define (op-num-num-bool? x) (member x op-num-num-bool))
;(define op-str-str  '(string-append ))


(define scm2cpp-primitives 
  (lset-union 
   eq?
   op-num-num-num
   op-num-num-bool
   op-str-str
   scheme-primitives 
    ))
(define (scm2cpp-primitive? op) (and (symbol? op) (memq op scm2cpp-primitives)))


;; (define number-prefix-alist 
;;   '(
;;     (char . u8)
;;     (short . s16)
;;     (int . s32)
;;     ;; (float . f32 )
;;     (float . f64 )
;;     (double . f64 )
;;     ))

;; (define (number-type->uvect t)
;;   (let ((v  (assoc t  number-prefix-alist )))
;;     (if v (string->symbol (string-append (symbol->string (cdr v)) "vector"))
;; 	'f64vector)))
  
;(define number-type-order-list null)
;(define number-type-order-alist null)



;; (define type-symbol-alist null)
;; (define (reset!type-symbol-alist)
;;   (set! number-type-order-list (map gensym number-type-base-name-order-list ))
;;   (set! number-type-order-alist (map cons  number-type-base-name-order-list number-type-order-list ))
;;   (set! 
;;    type-symbol-alist
;;    (append 
;;     number-type-order-alist 
;;     (map 
;;      (lambda (x) (cons x (gensym x))) 
;;      (append 
;;       compiler-tags 
;;       uvect-fix-length-types)))))
;; (reset!type-symbol-alist)


;; (define symbol-type-alist 
;;   (map (lambda (x) (cons (cdr x) (car x))) type-symbol-alist))
(define (type-symbol name) 
  (let ((kv (assoc name type-symbol-alist)))
    (if kv (cdr kv) name)))





 
(define rigid-types 
  (lset-union 
   eq?
   ;; '(number int float bool string char )
   ;;  '(string char?)
   (map cdr type-symbol-alist)
   number-type-order-list
   scm2cpp-primitives
   op-num-num-num
   op-num-num-bool
   op-str-str 
  ))
(define (rigid-type? t) 
  (if (equal? t Unknown)
      #f
      (member t rigid-types)))
;(define (non-fix-type? t) (or (rigid-type? t)  (pair? t)))




(define (var-non-fix-type? v env [unknown-typed-list unknown-type-list] )
  ;(let ([number-any-union-type? (make-number-any-union-type? unknown-typed-list)])
    (let loop((v1 v))
      (let ((vt (assoc v1 env)))
	(cond 
	 [(unknown-type? v1 unknown-typed-list) v1]
	 [(scheme-primitive? v1) #f]
	 [(rigid-type? v1) #f]
	 [ (not vt) #f] ;;ok? wrong?
	 [(unknown-type? (cdr vt) unknown-typed-list) (cdr vt)]
	 [(equal? v1 (cdr vt)) v1]
	 [(equal? v  (cdr vt)) v] ;;cyclic loop
	 ;[(number-any-union-type? (cdr vt)) => identity ]
	 [(type-unknown->number-any-union-type? (cdr vt) unknown-typed-list) => identity]
	 [else (loop (cdr vt))]
	 )  )))
  ;)
       
;; (var-non-fix-type? 'x '((x . x))); ->#f ?

(define (var-env-unknown->non-fix-type? v env-type unknown-typed-vars)
  (cond
   [(atom? v)    
    (let ([vt (assq v env-type)])
      (if vt 
	  (let ([t (cdr vt)])
	    (cond
	     [(eq? v t) v]
	     [(member v (flatten t)) t]
	     [(type-unknown->number-any-union-type? t unknown-typed-vars) t]
	     ;[(number-any-union-type? t) => identity ]
	     [(member v unknown-typed-vars) v]
	     [(rigid-type? t) t]
	     [(scheme-primitive? v) #f]
	     [else #f]
	     ))
	  #f))]
   [else #f]))

(define (var-env->direct-type v env)
  (let ((vt (assq v env)))
    (if vt (cdr vt) v)))

(define (var-env->type v env)
  (let (
	(vv (var-non-fix-type? v env) )
	(vt (assq v env))
	)
    (if vv
	vv
	(if vt 
	    (var-env->type (cdr vt) env)	    
	    v)))) 
;; (var-env->type 'y '((x . x)))




(define (expand-type t env)
  ;(display (list "expand-type0" t env))  
  (let (
	(vv (var-non-fix-type? t env) )
	(vt (assq t env))
	)
    (cond
     [vv vv]
     [vt (expand-type (cdr vt) env)]
     [(scheme-primitive? t) t]         
     [(rigid-type? t) t]
     [(pair? t)
      (cons (expand-type (car t) env)
	    (expand-type (cdr t) env))]
     [else  t])))

;(expand-type 'x `((x . (list (,Union  z (,Union 1 3 ) (,Union z 2)))) (y . y) (z . ,Double) ) )
;(expand-type 'x `((x . (,Union  x (,Union 1 3 ) (,Union z 2)))) )


(define force-template-types (list Number))
(define (force-template-type? t) (member t force-template-types))
;; (define ctype-alist '( (number . "double")  (float . "double" ) (string . "std::string")))
;; (define ctype-alist `( (,Number . "double")  (,Float . "double" )  (,Double . "double" )  (,Int . "int" ) (,Bool . "bool" ) (,Char . "char" )  (,String . "std::string") (,Void . "void")) )

(define (type->ctype t )
  (let ((kv  (assq t ctype-alist)))
    (if kv (cdr kv)
	(symbol->string t))))

;; (type->ctype 'number)
;; (type->ctype 'bool)





(define (var-declared-type? v env-inv-alpha env-inv-free)
  (let ((t (proctype (env2-rename v env-inv-alpha env-inv-free))))
    (not (or 
     (equal? t 'VAL)
     (equal? t 'val)))))

(define (var-alpha-free-type->type v env-inv-alpha env-inv-free env-type)
  (let ((t 
	 (proctype  ;;;; old scm2c type
	  (env2-rename v env-inv-alpha env-inv-free))))
    (if 
      (or 
       (equal? t 'VAL)
       (equal? t 'val))      
      (var-env->type v env-type)
      (schlep-type2type t))))

;; ;;;;debug
;; (set!declarations '())
;; (declare-names '( ("*int" int) ("*float"  float) ("*double" float)))
;; (proctype 'x-int)
;; (define debug-alpha '( (x-int . x-int ) (x-int1 . x-int) (y . y)))  
;; (define debug-free  '( (u . u ) (u1 . u) (v-double . v-double)))  
;; (define debug-type-env '((x . int) (u . x)))
;; (var-alpha-free-type->type 'x-int1 debug-alpha debug-free debug-type-env )
;; (var-alpha-free-type->type 'u1 debug-alpha debug-free debug-type-env )
      



;; (define (var-set-type-env->env v t env alpha free)
;;   (let ((v-t (assq v env))
;; 	(vt (var-env->type v env))
;; 	(tt (var-env->type t env))
;; 	(t-new (var-alpha-free-type->type v alpha free env))
;; 	)
;;     (when (not (var-declared-type? v alpha free))
;;      (set! t-new  (more-general-type vt tt)))
;;     ;(updage-type-env (cdr v-t) t-new 
;; 		     (alist-cons-update v t-new env)
;; 		     ;)
;;     ))



(define (alpha-free-exp->init-type-full-env  alpha free alpha-exp)
  (define env 
    (map (lambda (kv) 
	   (cons (car kv)
		 (map-tree type-symbol (cdr kv))))
	 (alpha-free->type-full-env ;;include old scm2c type force
	  alpha free)))
  (define (var v) (var-env->type v env))
  (define (typeup exp en)
    (match 
     exp
     [`(define (,F ,params ...) ,E ... )
      ;(display (list 'alpha-free-exp->init-type-full-env exp en))(newline)
      (let ((kv (assoc F en)))
	(when 
	 (and 
	  kv 
	  (var-declared-type? F alpha free))
	 (set! en
	       (alist-cons-update F (list 'lambda 
					  ;(map var params)  
					  params  
					  (cdr kv) ) en))))
      (typeup E en)
      en]
     [ (? pair? )  (typeup (cdr exp) (typeup (car exp) en))]
     [ _ en]))
  (typeup alpha-exp  env))

;; ;;;;debug
;; (define debug-alpha '( (x-int . x-int ) (x-int1 . x-int) (y . y)))  
;; (define debug-free  '( (u . u ) (u1 . u) (v-double . v-double)))  
;; (alpha2declaratype debug-alpha)
;; (alpha-declara->type-env  debug-alpha)
;; (alpha-declara->type-full-env debug-alpha)
;; (alpha-free->type-env debug-alpha debug-free)
;; (define debug-type (alpha-free->type-full-env debug-alpha debug-free))
;; (define debug-exp '(define (v-double) 123))
;; (define debug-exp '(() ( (define (v-double u1) 123)) u)
;; (alpha-free-exp->init-type-full-env debug-alpha debug-free debug-exp)




(define (reduce-unknown-type type-env)
  (define (u2t u t l)
    (if (null? l) l
	(if (pair? l)
	    (cons (u2t u t (car l)) 
		  (u2t u t (cdr l)))
	    (if (equal? l u) t l))))	
  (let ((t1  (filter (lambda (x) (unknown-type? (cdr x) )) type-env)))
    (if (null? t1) type-env
	(reduce-unknown-type (u2t (cdr (car t1)) (car (car t1)) type-env))
	)))


;; (define debug-env '((u . u) (v . int) (f lambda (u Unknown-Type45) Unknown-Type44) (x . Unknown-Type44) (z . Unknown-Type45) ))
;; (define unknown-type-list '(Unknown-Type44 Unknown-Type45) )
;; (unknown-type? 'Unknown-Type44)
;; (reduce-unknown-type debug-env)



;; (define (updage-type-env t-old t-new env)
;;   (map
;;    (lambda (vt) (let ((t (cdr vt)) (v (car vt)))
;; 		  (if (equal? t t-old) 
;; 		      (cons v t-new)
;; 		      vt)))   env))
;; ;; (updage-type-env 'u 'v '((x . u ) (y . int ) (z . u))) 





;; (define (var-type-env-renew->new-env v t env var-env-renew)
;;   (let (
;; 	(vv (var-non-fix-type? v env))
;; 	(tv (var-non-fix-type? t env))
;; 	(v-t (assoc v env))
;; 	(t-t (assoc t env))
;; 	(v->t (var-env->type v env))
;; 	(t->t (var-env->type t env))
;; 	)
;;     ;(display (list 'var-type-env-renew->new-env v t vv tv v-t t-t v->t t->t ))(newline)
;;     (cond
;;      [(rigid-type? v) env] ;;should not happen
;;      [(and vv tv) (assing-unknown-type->env tv v env)]
;;      [ vv         (assing-unknown-type->env vv t env)]
;;      [ tv         (assing-unknown-type->env tv v env)]
;;      [(equal? v->t t->t) env]
;;      [ v-t
;;        (let ((vt (cdr v-t)))
;; 	 (cond 
;; 	  [(and (pair? vt) (pair? t))
;; 	   (var-type-env-renew->new-env
;; 	    (cdr vt) (cdr t)
;; 	    (var-type-env-renew->new-env 
;; 	     (car vt) (car t) env var-env-renew)
;; 	    var-env-renew)]
;; 	  [(rigid-type? vt) (var-env-renew v t env)]
;; 	  [else (var-type-env-renew->new-env vt t env var-env-renew)]))]
;;      [else (alist-cons-update v t env)])))



;; (define (var-ref-type-env->env v t env) 
;;   (let (
;; 	;; (vv (var-non-fix-type? v env) )
;; 	(v-t (assq v env))
;; 	(vt (var-env->type v env))
;; 	(tt (var-env->type t env))
;; 	)
;;     (if (and (number-type? vt) (number-type? tt))
;; 	env
;; 	env ; tmp 
;; 	)))

;; (define (var-set-type-env->env v t env 
;; 			       ;env-init
;; 			       )
;;   (let ((v-t (assq v env))
;; 	;; (vt (var-env->type v env))
;; 	;; (tt (var-env->type t env))
;;         ;; (vv (var-non-fix-type? v env) )
;; 	;; (v-t0 (assq v env-int))
;; 	)
;;     ;(when (not (var-declared-type? v alpha free))
;;     ; (set! t-new  (more-general-type vt tt)))
;;     ;(updage-type-env (cdr v-t) t-new 
;;     ;(alist-cons-update v t-new env)
;;     ;; (if v-t
;;     ;;     (alist-cons-update v t env)
;;     ;;      env)
;;     ;;)
;;     (alist-cons-update v (more-general-type (cdr v-t) t) env)
;;     ))



;; (define (type-type-ref-match-renew t-var t-ref env 
;; 				   var-env-renew
;; 				   [update-types (lambda (t1 t2 e) t1) ]
;; 				   )
;;   ;(display (list 'type-type-ref-match-renew t-var t-ref env ))(newline)
;;   (let (
;; 	(vv (var-non-fix-type? t-var env))
;; 	(tv (var-non-fix-type? t-ref env))
;; 	(v-t (assoc t-var env))
;; 	(t-t (assoc t-ref env))
;; 	(v->t (var-env->type t-var env))
;; 	(t->t (var-env->type t-ref env))	
;; 	)
;;     (cond
;;      [(and vv tv) (set! env (assing-unknown-type->env tv t-var env)) (values tv env) ]
;;      [ vv         (set! env (assing-unknown-type->env vv t-ref env)) (values vv env) ]
;;      [ tv         (set! env (assing-unknown-type->env tv t-var env)) (values tv env) ]
;;      [(equal? t-var t-ref) (values t-var env)]
;;      [(equal? v->t t->t)   (values t-var env)]
;;      [(and (rigid-type? t-var) (rigid-type? t-ref)) (values (update-types t-var t-ref env) env) ]
;;      [(and (pair? t-ref) (pair? t-var))
;;       (let ((tr1 (car t-ref))
;; 	    (tr2 (cdr t-ref))
;; 	    (t1 (car t-var))
;; 	    (t2 (cdr t-var)))
;; 	(let*-values 
;; 	    ([(tt1 env1) (type-type-ref-match-renew t1 tr1 env  var-env-renew update-types)]
;; 	     [(tt2 env2) (type-type-ref-match-renew t2 tr2 env1 var-env-renew update-types)])
;; 	  (values (cons tt1 tt2) env2)))]
;;      [ v-t (type-type-ref-match-renew (cdr v-t) t-ref env  var-env-renew update-types)]
;;      [ t-t (type-type-ref-match-renew t-var (cdr t-t) env  var-env-renew update-types)]
;;      [(rigid-type? t-ref) (set! env (var-env-renew t-var t-ref env)) (values (update-types t-var t-ref env) env) ]
;;      [(rigid-type? t-ref) (set! env (var-env-renew t-ref t-var env)) (values (update-types t-var t-ref env) env) ]
;;      [(pair? t-var) (set! env (var-env-renew t-ref t-var env)) (values (update-types t-var t-ref env) env) ]
;;      [(pair? t-ref) (set! env (var-env-renew t-var t-ref env)) (values (update-types t-var t-ref env) env) ]
;;      [else (set! env (var-env-renew t-var t-ref env)) (values (update-types t-var t-ref env) env)]
;;      )))











(define (lambda-ref-analysis expr lnames)
  (define ref-lambdas '())
  (define (lam? x) (member x lnames))    
  (define (rupa l)
    (set! ref-lambdas (lset-union eq? ref-lambdas `(,l))))
  (define (la expr)
    (match 
     expr
     [ `(let ((,lname ,`(lambda ,params . ,E))),lname)
       (for-each la E)
       lname]
     [`(,(? lam? )) false]
     [`(,(? lam? )  ,E ...)
      (for-each la E) false]
     [`(map ,(? lam? o) ,E ...) 
      (for-each la E) false]
     [`(,O ,E ...) (or (map la E))]
     [(? lam?)
      (display expr)(newline)
      (rupa expr)
      expr]
     [ _ false]
     ))
  (la expr)
  ref-lambdas
  )

;; (lambda-ref-analysis 
;;  '(let ((lam (lambda (x y) (+ x y))))
;;     lam)
;;  '())

;; (lambda-ref-analysis 
;;  '(map l1 '(1 2))   
;;  '(l1 l2 l3))

;; (lambda-ref-analysis 
;;  'l1
;;  '(l1 l2 l3))




;(define (union-symbol? x)(eq? x Union))
;(define (number-symbol? x)(eq? x Number))











(define (type-env-match->type-env-rel-var-alist env-type [unknown-typed-list null])  
  (let* ([types  (map cdr env-type)]
	 [types-reify
	  (lset-union eq?
	   (reify-lset-list-in-sexp types);;;;extract like  _.1 _.2 ...
	   (map 
	    ;cdr 
	    car
	    (filter 
	     (lambda (kv) 
	       (let ([c (car kv)] [d (cdr kv)])
		 (or
		  (member c unknown-typed-list)
		  (eq? c d)
		  (member c (flatten d)) 
		  )
		 ))
	     env-type)))
	  ]
	 [env-symbol-rel-var-alist (map (lambda (x) (cons x (var x))) types-reify )]
	 [env-type-rel-var (map 
			   (lambda (x)
			     (cons
			      (car x)
			      (cl:sublis 
			       env-symbol-rel-var-alist 
			       (cdr x))))
			   env-type)])
    ;(display (list 'types-reify types-reify))(newline)
    (values 
     env-type-rel-var
     env-symbol-rel-var-alist 
     )
    ))

;; (type-env-match->type-env-rel-var '((x . x ) (y . x))) 


(define (type-env-match->type-env-rel-var env-type [unknown-typed-list null])  
  (call-with-values-ref0-arg type-env-match->type-env-rel-var-alist (list env-type unknown-typed-list)) )



(define (type-env->env-union-env-values env)  
;;;; flatten union tree using rename union  (gensym 'union)
  (define env-union '())
  (define (env-union-add x t) (lstack-push! (cons x t) env-union) x)
  (define (new-var) (gensym 'union))

  (define (union-extract expr)
    ;(display expr)(newline)
    (match
     expr
     [`(,(? union-symbol? U) ,E ...)
      (let ([x (new-var)]
	    [t (cons Union (map union-extract E))])
	(env-union-add x t)
	x)]
     [(? atom? )  expr]
     [(? pair? ) (cons (union-extract (car expr)) (union-extract (cdr expr)))]
     [ _ expr]
     ))
  (let ([env-new  (map (lambda (kv) (cons (car kv) (union-extract (cdr kv)))) env)])
    (values env-new env-union)))
  
;; Union

;; (type-env->env-union-env-values `((x . (,Union  z y)) (y . y) (z . ,Double) ) )
;; ;; => 
;; ;; '((x . union877) (y . y) (z . Double206))
;; ;; '((union877 Union217 z y))

;; (type-env->env-union-env-values `((x . (list (,Union  z (,Union 1 3 ) (,Union z 2)))) (y . y) (z . ,Double) ) )
;; ;; =>
;; ;; '((x list union878) (y . y) (z . Double206))
;; ;; '((union878 Union217 z union879 union880)
;; ;;   (union880 Union217 z 2)
;; ;;   (union879 Union217 1 3))
 



(define (type-env-match->type-env-rel-var--constraints--rel-var-alist env-match [unknown-typed-list null] [rel-constraints null])
  (define (add-rel-constraints p)(lstack-push! p rel-constraints))
  ;(define env-rel-var (type-env-match->type-env-rel-var env-match unknown-typed-list))
  (define-values
    (env-rel-var
     rel-var-alist)
    (type-env-match->type-env-rel-var-alist env-match unknown-typed-list))

  ;(display  (list 'env-rel-var (run* (q) (== q  env-rel-var))))(newline)
  (define reify-var-list (remove-duplicates (filter var? (flatten env-rel-var))))
  ;(display  (list 'reify-var-list (run* (q) (== q  reify-var-list))))(newline)
  (define-values (env-rel-var-union env-union) (type-env->env-union-env-values env-rel-var))
  ;(display  (list 'env-rel-var-union (run* (q) (== q  env-rel-var-union))))(newline)
  ;(display  (list 'env-union (run* (q) (== q  env-union))))(newline)
  (define env-union-rel-var-alist (map (lambda (kv) (cons (car kv) (var (car kv)))) env-union))
  (define env-union-rel (cl:sublis env-union-rel-var-alist env-union))
  (define env-rel (cl:sublis env-union-rel-var-alist env-rel-var-union))

  (define (u2c u-list)
    (if (null? u-list) '(())
	(let* (
	       [kv (car u-list)]	       
	       [v  (car kv)]
	       [u1 (cddr kv)]
	       [u2 (u2c (cdr u-list))]
	      ;(map (lambda (ps) (flatten ps)
	      [pselect? 
	       (lambda (i j)
		 (let ([vars (remove-duplicates (filter var? (flatten j)))])
		   (cond
		    [(null? (lset-intersection eq? vars u1)) true]
		    [(null? (lset-intersection eq? vars (flatten i))) false]
		    [else true]
		    )))]	       
	      )
	  ;(display (list u1 u2))
	  (for*/list
	   ([i u1]
	    [j u2]
	    #:when (pselect? i j)
	    )
	   (cons (cons v i) j)
	   ;(list i j)
	   ))))
  (define union-relation-alist       (u2c env-union-rel))
  ;(display union-relation-alist)(newline)

  (add-rel-constraints 
   (for-conde-kanren
    (map
     (lambda (l)
       (for-kanren
	(map 
	 (lambda (kv) (== (car kv) (cdr kv)))
	 l) )
       )
     union-relation-alist 
     )
    )
   )


  ;; (for-each
  ;;  (lambda (kv)  (add-rel-constraints (membero (car kv) (cddr kv) )))
  ;;  env-union-rel)
  (values
   env-rel
   rel-constraints
   rel-var-alist
   env-rel-var
   )
  )



(define (type-env-match->type-env-rel-var-constraints env-match [unknown-typed-list null] [rel-constraints null])
  (let-values(
	      [
	       (env-rel
		rel-constraints
		rel-var-alist
		env-rel-var)
	       (type-env-match->type-env-rel-var--constraints--rel-var-alist env-match unknown-typed-list rel-constraints)
	       ]
	      )
    (values
     env-rel
     rel-constraints   
     )
))
    

;; 

;; (type-env-match->type-env-rel-var-constraints  `((x . (,Union x ,Int) ) (y . (,Union x ,Number))) )

;; (let-values ([(e p) 
;; 	     (type-env-match->type-env-rel-var-constraints
;; 	      `(
;; 		;(,FunctionReturns) 
;; 		;(x . (,Union x ,Int) ) (y . (,Union x ,Number))
;; 		;(y . (,Union x ,Number)) (x . (,Union x ,Int) )
;; 		(y . y) (x . x ) 
;; 		)
;; 	      )])
;;   (let ([ret-env-type-rel-result	 
;; 	 (run* (q) 
;; 	       (for-kanren  (reverse p))
;; 	       (== q (cons (cdar e) e)))
;; 	   ])     
;;     ;ret-env-type-rel-result	     
;;     (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list ret-env-type-rel-result)     
;;     ))



;; (type-env-match->type-env-rel-var-constraints  `((x . x ) (y . y) ))



;; (for*/list (
;;       [i '(1 2 3)]
;;       ;[j '(4 5 )]
;;       [j '(())]
;;       )
;;      ;(display (list i j))
;;      (list i j)
;;      ;(cons i j)
;;      )



;(define;;  (union->constraints u-list ps )
;; (define (u2c u-list)
;;     (if (null? u-list) '(())
;; 	(let* (
;; 	      [u1 (car u-list)]
;; 	      [u2 (u2c (cdr u-list))]
;; 	      ;(map (lambda (ps) (flatten ps)
;; 	      [pselect? 
;; 	       (lambda (i j)
;; 		 (let ([vars (remove-duplicates (filter var? (flatten j)))])
;; 		   (cond
;; 		    [(null? (lset-intersection eq? vars u1)) true]
;; 		    [(null? (lset-intersection eq? vars (flatten i))) false]
;; 		    [else true]
;; 		    )))]	       
;; 	      )
;; 	  ;(display (list u1 u2))
;; 	  (for*/list
;; 	   ([i u1]
;; 	    [j u2]
;; 	    #:when (pselect? i j)
;; 	    )
;; 	   (cons i j)
;; 	   ;(list i j)
;; 	   ))))

;; (u2c '((1 2) (3 4) (5 6 7) ))





(define (type-env-rel->unknown-type-list env) (reify-lset-list-in-sexp (map cdr env)))

(define (type-env-rel->untype-varname-alist env-rel)
 (type-env-unknown-type-list->untype-varname-alist 
  env-rel 
  (type-env-rel->unknown-type-list env-rel)))

(define (type-env-unknown-type-list->untype-varname-alist type-env unknown-type-list)
 ;(display (list type-env unknown-type-list))(newline)
  (let* (
	 [type-env-rev 
	 (reverse ;;; note rev ;;be careful
	  (map (lambda (x) (cons (cdr x) (car x))) type-env)
	  )
	 ]
	[untype-varname-alist   
	 (let untype-varname-alist-rec 
	     ((alis '()) (rest unknown-type-list))
	   ;(display type-env-rev)(newline)
	   ;(display alis)(newline)
	   (if (null? rest)
	       alis
	       (let* ([ut (car rest)]
		      [uv (assoc ut type-env-rev)];;be careful]
		      [vv (if 
			   (and (pair? uv) (symbol? (cdr uv))) (cdr uv)
			   (gen-unknown-type);;;affect general var unknown-type-list
			      )])
		 ;(display (list ut v vv))(newline)
		 (untype-varname-alist-rec (alist-no-overwrite-update ut vv alis) (cdr rest)))))]
)
    ;(display type-env-rev)(newline)
    untype-varname-alist
))



(define (type-env-rel--unknown-typed-list->rigid-untype-varname-alist type-env-rel unknown-typed-list 
								      ;other-env-match-list
								      )
 ;(display (list type-env-rel unknown-typed-list))(newline)
  (let* (
	 [type-env-rel-rev 
	 (reverse ;;; note rev ;;be careful
	  (map (lambda (x) (cons (cdr x) (car x))) type-env-rel)
	  )
	 ]
	[untype-varname-alist   
	 (let untype-varname-alist-rec 
	     ((alis '()) (rest unknown-typed-list))
	   ;(display type-env-rel-rev)(newline)
	   ;(display alis)(newline)
	   (if (null? rest)
	       alis
	       (let* ([ut (car rest)]
		      [uv (assoc ut type-env-rel-rev)];;be careful]
		      )
		 ;(display (list ut uv))(newline)
		 (if 
		  (and (pair? uv) (symbol? (cdr uv)))
		  (untype-varname-alist-rec (alist-no-overwrite-update ut (cdr uv) alis) (cdr rest))
		  (untype-varname-alist-rec alis (cdr rest))
		  ))
	       ))		 
	 ]
	)
    ;(display type-env-rel-rev)(newline)
    untype-varname-alist
))

;; (type-env-rel--unknown-typed-list->rigid-untype-varname-alist '((x . _.1 ) (y . _.1 ) (z . _.3) ) '(_.1 _.2 _.3)) ;=> '((_.1 . y) (_.3 . z))

(define (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list type-ret-env-rel-list)
  (let* 
      (

       [ret--env--rigid-alist--non-rigid-alist--list
    	 (map
    	  (lambda (ret-env-rel)
    	    (let* (
    		 [ret-rel (car ret-env-rel)]
    		 [env-rel (cdr ret-env-rel)]
    	  	 [unknown-typed-list-rel
		  (lset-union eq?
		   (type-env-rel->unknown-type-list env-rel)
		   (reify-lset-list-in-sexp ret-rel))
		  ]
    		 [rigid-untype-varname-alist
    		  (
		   type-env-rel--unknown-typed-list->rigid-untype-varname-alist
		   ;type-env-unknown-type-list->untype-varname-alist 
		   env-rel unknown-typed-list-rel)]

    		 [rigid-unknown-typed-list-rel (map car rigid-untype-varname-alist)]
    		 [non-rigid-unknown-typed-list-rel (lset-difference eq? unknown-typed-list-rel      rigid-unknown-typed-list-rel)]
		 [non-rigid-untype-varname-alist (map (lambda (x) (cons x (var (gensym))))    non-rigid-unknown-typed-list-rel)]

    		 ;[rigid-unknown-typed-list (append unknown-typed-list-rel (map cdr untype-varname-alist))]
    		 [env1 (cl:sublis     rigid-untype-varname-alist  env-rel)]
    		 [ret1 (cl:sublis     rigid-untype-varname-alist  ret-rel)]
    		 [env  (cl:sublis non-rigid-untype-varname-alist  env1)]
    		 [ret  (cl:sublis non-rigid-untype-varname-alist  ret1)]
    		 )
	      ;(set! unknown-typed-list-total (remove-duplicates (append unknown-typed-list unknown-typed-list-total)))
    	      ;(display untype-varname-alist)(newline)
    	      ;(cons ret env)
	      (list ret env rigid-untype-varname-alist non-rigid-untype-varname-alist
		    ;non-rigid-unknown-typed-list-rel rigid-unknown-typed-list-rel
		    )
	      ))
	   (refine-rel-conditional-result type-ret-env-rel-list)
    	  )
	 ]
       [non-rigid-untype-var-list 
	(flatten 
	 (map (lambda (e)(map cdr (list-ref e 3))) 
	      ret--env--rigid-alist--non-rigid-alist--list))
				  ]
       [non-rigid-untype-var-kanren-condition
	(map (lambda (v) (varo v)) non-rigid-untype-var-list )]

       [non-rigid-untype-function-return-type-var-list
	(flatten
	 (map (lambda (e)(filter var? (cdr 
				       (cond [(assoc FunctionReturns (list-ref e 1)) => identity]
					     [else `(,FunctionReturns . ())])
				       ))) ret--env--rigid-alist--non-rigid-alist--list))]

       [ret--env--rigid-alist--non-rigid-alist--reduce-list
	(let ret--env--rigid-alist--non-rigid-alist--reduce ([lst  ret--env--rigid-alist--non-rigid-alist--list  ])
	  ;(display lst)(newline)
	  ;(display non-rigid-untype-var-kanren-condition)(newline)	  
	  (cond
	   [(null? lst) '()]	   
	   [else
	    (let* ([e0 (car lst)]
		   [e1 (cdr lst)]
		   [e0r (car e0)]
		   [e0e (cadr e0)]
		   [e2
		    (filter
		     (lambda(e)
		       ;(display e)(newline)	
		       (let ([er (car e)][ee (cadr e)])
			 ;(display (list ee e0e er e0r))(newline)
			 (if (null? non-rigid-untype-var-kanren-condition)
			     (not (equal? (list er ee) (list e0r e0e)))
			     (null? (run* (q)
					  (for-kanren  
					   (append
					    (list (== ee e0e) (== er e0r)) 
					    non-rigid-untype-var-kanren-condition ) ))))))
		     e1)])
	      ;(display e2)(newline)	
	      (cons e0 (ret--env--rigid-alist--non-rigid-alist--reduce e2)
	       ))]))]
       [non-rigid-untype-var-reduce-list 
	(flatten
	 (map (lambda (e)(map cdr (list-ref e 3))) 
	      ret--env--rigid-alist--non-rigid-alist--reduce-list))]
       [non-rigid-untype-var-single-appear-list
	(let ([l (flatten
		  (map (lambda (e)(list (car e) (cadr e)))
		       ret--env--rigid-alist--non-rigid-alist--reduce-list))])
	  (filter
	   (lambda (x)
	     (= (count (lambda (y) (equal? x y)) l) 1))
		       non-rigid-untype-var-reduce-list))
	 ]
       
       [env-var-list1
	(foldl
	 (lambda (re lst)
	   (lset-union equal?
		       (map car (cadr re))
		       lst))
    	   '()
    	   ;ret-env-match-list
	   ret--env--rigid-alist--non-rigid-alist--reduce-list
    	   )]
       [env-var-list (remove FunctionReturns env-var-list1)]
       [refine-var-alist '()]
       [env-union-semi-rel
       	  (map
       	   (lambda (x)	    
       	     (cons 
       	      x 
	      (let-values
		  ([(r a)
		    ;; type-list->union
		    (type-list->union-refine
		     (map
		      (lambda (re)
			(let ([kv (assoc x (cadr re))])
			  (if kv (cdr kv) (list Union))))
		      ret--env--rigid-alist--non-rigid-alist--reduce-list
       		;ret-env-match-list
		      ) refine-var-alist 
			non-rigid-untype-function-return-type-var-list
			) ])
		(set! refine-var-alist a)
		 r) ))
       	   env-var-list)]
       ;; [env-union-semi-rel
       ;; 	(remove
       ;; 	 (assoc FunctionReturns env-union-semi-ck1)
       ;; 	 env-union-semi-ck1
       ;; 	 )]

       [ret-union-semi-rel
	(let-values
	    ([(r a)
	      ;; type-list->union
	      (type-list->union-refine
	       (map 
		car
		ret--env--rigid-alist--non-rigid-alist--reduce-list
		;; ret-env-match-list
		)
	       refine-var-alist
	       non-rigid-untype-function-return-type-var-list
	       )])
	  (set! refine-var-alist a)
	  r
	  )]
       [non-rigid-untype-varname-reverse-alist
	(map (lambda (x)
	       (cons x 
		     (gen-unknown-type);;;affect general var unknown-type-list
		     ))
	       non-rigid-untype-var-reduce-list )
	]
       [env-union-match (cl:sublis non-rigid-untype-varname-reverse-alist env-union-semi-rel)]
       [ret-union-match (cl:sublis non-rigid-untype-varname-reverse-alist ret-union-semi-rel)]
       [rigid-untype-varname-alist-total
       	(apply 
       	 lset-union 
       	 (cons eq?
       	       (map (lambda (l)(map cdr (list-ref l 2))) ret--env--rigid-alist--non-rigid-alist--reduce-list)))]
       [unknown-typed-list-total
       	(append
	 rigid-untype-varname-alist-total
	 (lset-intersection
	  eq?
	  (flatten env-union-match)
	  (flatten ret-union-match)
	  (map cdr non-rigid-untype-varname-reverse-alist)
	 ))	
	]	
       )

    ;; (newline)
    ;; (display
    ;;  (list 
    ;;   'type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list 
    ;;   ;type-ret-env-rel-list
    ;;   (length ret--env--rigid-alist--non-rigid-alist--list)
    ;;   (length ret--env--rigid-alist--non-rigid-alist--reduce-list)
    ;;   (length env-union-semi-rel)      
    ;;   ))
    ;; (newline)
    ;; ;(display env-union-semi-rel)     
    ;; ;;  env-var-list
    ;; ;; ;;  ;ret--env--rigid-alist--non-rigid-alist--reduce-list
    ;; ;; ) 
    ;; ;(display ret--env--rigid-alist--non-rigid-alist--reduce-list)
    ;; (display env-union-match)
    ;; (newline)
    ;; (display ret-union-match)
    ;; (newline)
    ;; (display unknown-typed-list-total)(newline)
    
    ;; (list 
    ;;  ; (cdar 
    ;; ;; 	   ret--env--rigid-alist--non-rigid-alist--list
    ;; ;; 	   ;)
    ;; ;; 	  ;(cdar 
    
    ;; ret--env--rigid-alist--non-rigid-alist--reduce-list
    ;; env-var-list
    ;; non-rigid-untype-var-reduce-list 
    ;; non-rigid-untype-var-single-appear-list
    ;; ;env-union-semi-rel
    ;; ;ret-union-semi-rel
    ;; env-union-match
    ;; ret-union-match
    ;; rigid-untype-varname-alist-total
    ;; unknown-typed-list-total
    ;; ;; 					;)
    ;; ;; 	  ;non-rigid-untype-var-kanren-condition
    ;; )
    (values
     env-union-match
     ret-union-match
     unknown-typed-list-total)
    
  ))


;; ;; (type-ret-env-rel-list->type-ret-env-match-list--unknown-typed-list-total
;; (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list
;;    `( (_.0 .  ( (,FunctionReturns)  (x . _.1 ) (y . (list _.3 _.4 )) (z . _.3) ) ) (_.0 .  ((,FunctionReturns) (x . _.0 ) (y . _.1 ) (z . _.3) ) ) )
;;  )

;; (type-ret-env-rel-list->type-ret-env-match-list--unknown-typed-list-total
;;  '( (_.0 .  ((x . _.1 ) (y . (list _.3 _.4 )) (z . _.3) ) ) 
;;     (_.0 .  ((x . _.0 ) (y . _.1 ) (z . _.3) ) ) 
;;     (_.1 .  ((x . _.1 ) (y . _.0 ) (z . _.4) ) )
;;     )
;; )

;; (type-ret-env-rel-list->type-ret-env-match-list--unknown-typed-list-total
;;  '( (_.0 .  ((x . _.1 ) (y . (list _.3 _.4 )) (z . _.3) ) ) 
;;     (_.0 .  ((x . _.0 ) (y . _.1 ) (z . _.3) ) ) 
;;     (_.1 .  ((x . _.1 ) (y . _.0 ) (z . _.4) ) )
;;     (_.0 .  ((x . _.2 ) (y . (list _.3 _.5 )) (z . _.3) ) )
;;     (_.1 .  ((x . _.1 ) (y . _.0 ) (z . _.5) ) )
;;     )
;; )




;; (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list
;;  '( (_.0 .  ((x . _.1 ) (y . (list _.3 _.4 )) (z . _.3) ) ) 
;;     (_.0 .  ((x . _.0 ) (y . _.1 ) (z . _.3) ) ) 
;;     (_.1 .  ((x . _.1 ) (y . _.0 ) (z .  1) ) )
;;     (_.0 .  ((x . _.2 ) (y . (list _.3 _.5 )) (z . _.3) ) )
;;     (_.1 .  ((x . _.1 ) (y . _.0 ) (z . _.5) ) )
;;     )
;; )
;; unknown-type-list  

;; (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list
;;  '( (Void835  . ( (i . _.0) (n . _.1) (m . _.2) (loop lambda () Void835)) ) 
;;     (_.0 . ((i . _.1) (n . _.2) (m . Int830) (loop lambda () _.0)))
;;     (_.0 . ((i . _.1) (n . _.2) (m . _.3) (loop lambda () _.0)))))





(define (type-env-rel->type-env-match env-rel)
  (let ([untype-varname-alist (type-env-rel->untype-varname-alist env-rel)])
    (cl:sublis untype-varname-alist  env-rel)))


;; (type-env-rel->type-env-match '((x . _.0) (y . _.1) )
;; (type-env-rel->type-env-match '((x . _.0) (y . _.1) )


;; ;;;;;usage debug 
;unknown-type-list  

;; (define expr-org '(begin (if x y z) u (list v w)))

;; (define-values (env-type gloal-ret-type unknown-type-list expr-alpha env-alpha-inv env-free-inv)   (infer-type-from-org-expr expr-org ))

;; env-type
;; (define tmp (type-env-rel->untype-varname-alist env-type) )
;; tmp
;; (cdr (assoc 'main env-type))
;; (type-env-rel->type-env-match env-type)
    
    


;; (define (type-set->union types)
;;   (if (= (length types) 1)
;;       types
      

;;   (match 
;;    types
;;    [() ]
;; ))


(define (env-ret-rel-result->env-ret-unknown-type-list-values  env-rel ret-rel)
	  (let* (
		 ;[ret-rel (caar ret-env-type)]
		 ;[env-rel (cdar ret-env-type)]
	  	 [unknown-type-list-rel
		  (type-env-rel->unknown-type-list env-rel)]
					;(reify-lset-list-in-sexp (map cdr env))))
		 [untype-varname-alist
		  (type-env-unknown-type-list->untype-varname-alist env-rel unknown-type-list-rel)]
		 [unknown-type-list (append unknown-type-list-rel (map cdr untype-varname-alist))]
		 [env (cl:sublis untype-varname-alist  env-rel)]
		 [ret (cl:sublis untype-varname-alist  ret-rel)]
		 )
      	  (values
	   env ret unknown-type-list
      	   ;(cdar ret-env-type)       
   	   ;(caar ret-env-type)
      	   ;(reify-lset-list-in-sexp ret-env-type)
	   ;(reify-lset-list-in-sexp (map cdr (cdar ret-env-type)))	   
	   )))

;; (let* ([x (var 'x) ] [ env `(( x . ,x)  ( y . ,x) )] [ret 'y]) 
;;   (env-ret-rel->env-ret-unknown-type-list-values  env ret))
;; ;;;wrong
;;(env-ret-rel->env-ret-unknown-type-list-values  '((x . _.0) (y . _.1))  '_.1)




(define (more-general-number-type-rel x y)
  (<=in-order-list y x number-type-order-list))


(define (more-general-number-type-o-rel x y o)
  ;(scm?->rel number-type? x)
  (conda
   ;[(== y Optional) fail]
   ;[(== x Optional) fail]   
  ;(conda
   [(varo* x)
    (conda
     [(varo* y)    ;; Committed choice: with unresolved operands the result is tied
     ;; to the first; conde tried both, doubling the search at every
     ;; arithmetic site.  Later constraints still refine the choice.
     (conda [(== x o)][(== y o)])]
     [(scm?->rel number-type? y)  ;; Committed choice: with unresolved operands the result is tied
     ;; to the first; conde tried both, doubling the search at every
     ;; arithmetic site.  Later constraints still refine the choice.
     (conda [(== x o)][(== y o)]) ] 
     ;[(== y Optional)  fail]     
     )]
   [(varo* y)
    ;(conda 
     ;[
      (scm?->rel number-type? x)  ;; Committed choice: with unresolved operands the result is tied
     ;; to the first; conde tried both, doubling the search at every
     ;; arithmetic site.  Later constraints still refine the choice.
     (conda [(== x o)][(== y o)]) 
      ;]
     ;[(== x Optional) fail]
    ;;; Committed choice: with unresolved operands the result is tied
     ;; to the first; conde tried both, doubling the search at every
     ;; arithmetic site.  Later constraints still refine the choice.
     (conda [(== x o)][(== y o)])
     ;)
    ]
   [
    ;(scm?->rel number-type? x)
    ;(scm?->rel number-type? y)
    (<=in-order-list y x number-type-order-list) (== o x)
    ]
   [
    ;(scm?->rel number-type? y)
    ;(scm?->rel number-type? x)
    (<=in-order-list x y number-type-order-list) (== o y)
    ]
  ))



;number-type-order-list

(define (most-general-number-type-list-o-rel lst q)
  (reduceo more-general-number-type-o-rel lst q))
  
;;   (conda
;;    [(<=In-order-list y x number-type-order-list) (== o x)]
;;    [(<=in-order-list x y number-type-order-list) (== o y)]
;;   ))


(define (more-shrink-union-than? t1 t2)
  (cond
   [(and (number-type? t1) (number-type? t2))
    (special-number-type>? t1 t2)]
   [ (number-type? t1) true]
   [ (number-type? t2) false]
   [else
    ( < (length (flatten t1))
        (length (flatten t2)) )]))

;; (sort 
;;  (list Int (list Union 1 2) Double (list Union 1 2 3) Float )
;;  ;(list Double Float Int)
;;  more-shrink-union-than? )
      ;(number-type? Int)
(define (type-type-list->most-shrink-union type type-list [refine-alist '()] [removable-type-list '()])
  (let-values ([
	(ret refine) 
	(type-type-list->most-shrink-union--refine type type-list refine-alist removable-type-list)])
    ret))


(define (type-type-list->most-shrink-union--refine type type-list [refine-alist '()] [removable-type-list '()])
  (let* ([type-list2 
	  (map
	   (lambda (t)
	     (cons (list t type)
		   (let-values ([
		     (ret refine1)
		     (type-type->union-refine (cl:sublis refine-alist type) (cl:sublis refine-alist t) refine-alist removable-type-list)])
		     (set! refine-alist refine1)
		     ret)
		   ))
	   type-list)]
	 [type-list3 
	  (sort (cl:sublis  refine-alist  type-list2)
	    (lambda (l1 l2)
	     (<
	      (-
	       (length (flatten (cdr l1)))
	       (length (flatten (car l1))))
	      (-
	       (length (flatten (cdr l2)))
	       (length (flatten (car l2)))))))])
    (values type-list3 refine-alist)
    ))

;; (let ([tmp  
;;        (type-type-list->most-shrink-union '(list 7) (list `(list (,Union 5 7)) 0 1 '(list 9)))
;;        ])
;;       (map 
;;        (lambda (l1) 
;; 	 (-
;; 	  (length (flatten (cdr l1)))
;; 	  (length (flatten (car l1)))))
;;        tmp))
;; (cdar (type-type-list->most-shrink-union '(list 7) (list `(list (,Union 5 7)) 0 1 '(list 9))))
;; (map caar (cdr (type-type-list->most-shrink-union '(list 7) (list `(list (,Union 5 7)) 0 1 '(list 9)))))

(define (type-type->union type1 type2 [refine-alist '()] [removable-type-list '()]) 
  (let-values
      ([(t r)
	(type-type->union-refine type1 type2 refine-alist removable-type-list)])
    t))



(define (type-type->union-refine type1 type2 [refine-alist '()] [removable-type-list '()])

  ;(display (list type1 type2 'type-type->union))(newline)

  ;; (define (remove-top-union t)    
  ;;   (match 
  ;;    t
  ;;    [`(,(? union-symbol? U) ,E ...)
  ;;     (lset-union equal? E )]
  ;;    [ _ t])
  ;;   )

  (define (t-t->u t1 t2)
	(let-values 
	    ([(ret refine1) (type-type->union-refine t1 t2 refine-alist removable-type-list)])
	  (set! refine-alist refine1)
	  ret))


  (define (merge-union t-top t-rest)
    (match 
     t-top
     [`(,(? union-symbol? U) ,E ...)
      (set! t-rest (lset-union equal? E t-rest))]
     [ _ (lstack-push! t-top t-rest)])
    (cons Union (remove-duplicates t-rest)))

  (set! type1 (cl:sublis  refine-alist type1))
  (set! type2 (cl:sublis  refine-alist type2))


  (let ([total-return-type
  (match (list type1 type2)
   [`(,X ,X) X]

   [(list (? number-type? X) (? number-type? Y))
    (more-general-number-type X Y)]

   [(list (? var? X) (? var? Y)) 
    ;`(,Union ,X ,Y)
    ;; (cond
    ;;  [(assoc Y refine-alist) => (lambda (kv) (cdr kv))
    ;; 	(assoc 
    (set! refine-alist  (alist-cons-update Y X refine-alist ))
    X
    ]

   [(or 
     (list   (? (lambda (x)(member x removable-type-list))  Y) X)
     (list X (? (lambda (x)(member x removable-type-list))  Y)  ) )
     (set! refine-alist  (alist-cons-update Y X refine-alist ))
     X
    ]


   [`(,(? atom? X) ,(? atom? Y)) `(,Union ,X ,Y) ]
   [`((,(? union-symbol? U) ,E1 ...)(,(? union-symbol? U) ,E2 ...))
    ;(display (list E1 E2 'union))(newline)
    (let ([us '()])
      (for 
       ([x E1])
       (let-values ([(z refine-alist1)
		     (type-type->union-refine x type2 refine-alist removable-type-list)])
	 (set! refine-alist refine-alist1)
	 (set! type1 (cl:sublis  refine-alist type1))
	 (set! type2 (cl:sublis  refine-alist type2))
	 (set! us (cl:sublis  refine-alist us))
   	 (match 
	  z
	  [`(,(? union-symbol? U) ,E ...)
   	   (set! us (lset-union equal? E us))]
   	  [ _ (set! us (cons z us))])	 
   	 ))
      (cons Union (remove-duplicates us)))]
    ;; (let ([us '()])
    ;;   (for* ([x E1] [y E2])
    ;;    (let ([z (type-type->union x y)])
    ;; 	 (match z
    ;; 	  [`(,(? union-symbol? U) ,E ...)
    ;; 	   (set! us (lset-union equal? E us))]
    ;; 	  [ _ (set! us (cons z us))])	 
    ;; 	 ))
    ;;   (cons Union (remove-duplicates us)))]
   [(or
    `((,(? union-symbol? U) ) ,y)
    `(,y ( ,(? union-symbol? U)))
    )
    y
    ]
   [(or
    `((,(? union-symbol? U) ,E1 ...) ,y)
    `(,y ( ,(? union-symbol? U) ,E1 ...))
    )
    ;(display (list E1 y 'union))(newline)
    (let*-values
	([(sorted-type-union-type-list refine1)
	    ;(type-type-list->most-shrink-union y E1 refine-alist)
	    (type-type-list->most-shrink-union--refine y E1 refine-alist removable-type-list)
	    ]
	 [(union-top)
	  (cdar sorted-type-union-type-list) ]
	 [(union-rest) (map caar (cdr sorted-type-union-type-list)) ]
	 )
      (set! refine-alist refine1)
      (merge-union 
       union-top 
       union-rest
       )
      ;(display (list union-top union-rest))(newline)
      ;(cons Union (remove-duplicates (append union-top union-rest) ))
      )
    ]
   ;; (let ([us '()])
   ;;    (for ([x E1])
   ;;     (let ([z (type-type->union x y)])
   ;; 	 (match z
   ;; 	  [`(,(? union-symbol? U) ,E ...)
   ;; 	   (set! us (lset-union equal? E us))]
   ;; 	  [ _ (set! us (cons z us))])
   ;; 	 ))
   ;;    (cons Union (remove-duplicates us)))]
   ;; ;; [ `(,y ,(? union-symbol? U) ,E1 ...)) 
   ;; ;;   (type-type->union type2 type1)]
   [`((lambda ,Para1 ,Ret1)(lambda ,Para2 ,Ret2))
    `(lambda ,(cdr (t-t->u `(list . ,Para1) `(list . ,Para2)))
       ,(t-t->u Ret1 Ret2))]

    

    
   [`((,X . ,E1)(,X . ,E2))
    (cons 
     X
     (let loop ((e1 E1) (e2 E2))
      (cond
       [(and (null? e1) (null? e2)) '()] 
       [(null? e1)(list Union Null e2)]
       [(null? e2)(list Union Null e1)]
       [(and (atom? e1) (atom? e2))
	(let-values 
	    ([(ret refine1) (type-type->union-refine e1 e2 refine-alist removable-type-list)])
	  (set! refine-alist refine1)
	  ret)]       
       [(atom? e1)(list Union e1 e2)]
       [(atom? e2)(list Union e1 e1)]
       [else
	(let-values 
	    ([(ret refine1) (type-type->union-refine (car e1) (car e2) refine-alist removable-type-list)])
	  (set! refine-alist refine1)
	  (cons ret (loop (cdr e1) (cdr e2))))]))
     )
    ;; (map
    ;;  (lambda 

    ;; (let-values 
    ;; 	([(ret refine1) (type-type->union-refine E1 E2 refine-alist)])
    ;;   (set! refine-alist refine1)	
    ;; `(,X . ,ret))
    ]

   ;; [`((,X ,E1 ...) (,Y ,E2 ...))
   ;;  (let-values 
   ;; 	([(ret refine1) (type-type->union-refine E1 E2 refine-alist)])
   ;;    (set! refine-alist refine1)	
   ;;  `(,X . ,ret))
   ;;  ;; (map 
   ;;  ;;  type-type->union 
   ;;  ;;  E1 E2)
   ;;  ]

   [ _ 
     (list Union type1 type2)]
   )
  ])
	
    (values total-return-type refine-alist)
	)
  ;; (match 
  ;;  type1
  ;;  [`(,Union ,E1 ...)
  ;;   (match 
  ;;    type2
  ;;    [`(,Union ,E2 ...)
  ;;     `(,Union . ,(lset-union equal? E1 E2))]     
  ;;    [ _  `(,Union . ,(lset-adjoin equal? E1 type2))])]

  ;;  [ _ 
  ;;   (match 
  ;;    type2
  ;;    [`(,Union ,E2 ...)
  ;;     `(,Union . ,(lset-adjoin equal? E2 type1))]
  ;;    [ _  `(,Union . ,(lset-adjoin equal? (list type2) type1))])])
)

;; ;(lset-adjoin equal? '(a b c d c e) 'a 'e 'i 'o 'u)


;; (type-type->union-refine 1 2)
;; (type-type->union 1 2)
;; (type-type->union '(list 1) '(list 2) )
;; (type-type->union '(list 1) '(list 1 3) )
;; (type-type->union '(list 1 2) '(make-list 1 2) )

;; (type-type->union '(list 1 1) '(list 2 1) )
;; (type-type->union '(list 1 1) '(list 1 3) )
;; (type-type->union `(,Union 1 2) `(,Union 1 2))
;; (type-type->union `(,Union 1 5) `(,Union 1 2))
;; (type-type->union `(,Union 1 2) 1)
;; (type-type->union `(,Union 1 2) 5)
;; (type-type->union '1 `(,Union 1 2) )
;; (type-type->union  3 `(,Union 1 2) )
;; (type-type->union  1 `(list 3 2) )
;; (type-type->union `(list (,Union 5 7)) '(list 7))
;; ;(Union1228 (list (Union1228 5 7)) 0 1 (list 7)) 
;; (type-type->union `(,Union ) 5)
;; (type-type->union `(list (,Union 1 5)) `(list (,Union 1 2)))
;; (type-type->union 1 `(,Union 0 (list (,Union 5 7))))
;; (type-type->union '(list 1 1) '(list 2 1) )
;; (type-type->union '(9 1 1) '(10 2 1) )



;; (type-type->union Number Int)
;; (type-type->union Double Int)

;; (let ([x (var 1)] [y (var 2)])
;;   (let-values ([(t a)
;; 		(type-type->union-refine (list 1 x 2) (list 1 y 3) )])
;;     t
;;     (eq? (cadr t) (cdar a))
;;     )
;;   ) 

;; (let ([x (var 1)] [y (var 2)])
;;   (let-values ([(t a)
;; 		(type-type->union-refine `(list . ,x ) `(list . ,y) )])
;;     (list t a)
;;     ;(eq? (cadr t) (cdar a))
;;     )
;;   ) 

;; (type-type->union-refine '(1 x y 3) '(1 2 3 1) '() '( x  y))
  

;(type-type->union-refine '(lambda (1 2 3) 4) '(lambda (2 3 3) 5 ))



;(+ #f #t)



(define (type-list->union-refine ts [refine-alist '()] [removable-type-list '()])
  (let (
	[ret
	 (foldl 
	  (lambda (e e0)
	    (let-values([(r a)
			 (type-type->union-refine e e0 refine-alist removable-type-list)])
	      (set! refine-alist a)
	      r))
	  `(,Union )
	  (sort ts more-shrink-union-than? )
	 )])
    (values ret refine-alist)))

;(define (types->union . ts)  (foldl type-type->union `(,Union ) (sort ts more-shrink-union-than? )))
;(define (type-list->union ts) (foldl type-type->union `(,Union ) (sort ts more-shrink-union-than? )))
(define (type-list->union ts [refine-alist '()] [removable-type-list '()]) 
  (let-values ([(r a)
		(type-list->union-refine ts refine-alist removable-type-list )])
    r))

(define (types->union . ts) (type-list->union ts) )


;; (type-list->union (list 1 4  `(,Union 1 2) `(,Union 1 3)))
;; (types->union 1 4  `(,Union 1 2) `(,Union 1 3))
;; (types->union `(list (,Union 5 7)) 0 1 '(list 7)) 
;; (types->union `(list (,Union 5 7)) '(list 7)) 

;; (sort (list Number 'x Int ) more-shrink-union-than? )

;(types->union Number 'x Int ) 
;(types->union Number Int ) 



(define (type-unknown->number-any-union-type? t unknown-vars)
  (match t
   [
    ;`(,(? union-symbol? U) ,(? number-symbol? N)  ,X )
    `(,(? union-symbol? U) ,(? number-type? N)  ,X )
    (if (member X unknown-vars) X false)
    ]
   [
    ;`(,(? union-symbol? U) ,X ,(? number-symbol? N)  )
    `(,(? union-symbol? U) ,X ,(? number-type? N)  )

    (if (member X unknown-vars) X false)
    ]
   [ _ false]
   ))

;; (type-unknown->number-any-union-type? (list Union Double 'x)  '(x y))

(define (make-number-any-union-type? unknown-vars)
  (lambda (t) 
    (type-unknown->number-any-union-type? t unknown-vars)))


;; (let ([number-any-union-type? (make-number-any-union-type? '(x y z))])
;;   ;(number-any-union-type? 1)
;;   (number-any-union-type? (list Union Number 'y))
;;   )


(define (optional-union-type? t)
  (match 
   t
   [`(,(? union-symbol? U) ,(? bool-symbol? B)  ,X ) X]
   [`(,(? union-symbol? U)   ,X ,(? bool-symbol? B)) X]
   [ _ false]))


;; (optional-union-type? 1)
;; (optional-union-type? (list Union Bool 11))
;; (optional-union-type? (list Union 12 Bool))


(define (vars-typeenv-unknown->unknown-types vars env-type unknown-typed-list)
  (remove-duplicates
   (lset-intersection
    eq? 
    (flatten (map (curryr var-env->direct-type env-type) vars))
    unknown-typed-list)
   ))





;; ;(define (list-correspond lst1 lst2)
(define (union-types-difference-correspond lst1 lst2 [unknown-typed-vars null])
  (let ((result '()))
    (let loop ((lst1 lst1)
	       (lst2 lst2))
      (display (list lst1 lst2))(newline)
      (cond 
       ;;(type-unknown->number-any-union-type? t unknown-typed-vars)

       [(null? lst1) '()]
       [(eq? lst1 lst2) '()]
       [(equal? lst1 lst2) '()]
       [(atom? lst1) (list (cons lst1 lst2))]
       [(atom? lst2) (list (cons lst1 lst2))]
       [else
	(match 
	 (list lst1 lst2)       
	 [`(,X ,X) '()]
	 [`((,(? union-symbol? U) ,E1 ...)(,(? union-symbol? U) ,E2 ...))
	  (let* ([u1 (lset-difference equal? E1 E2)]
		 [u2 (lset-difference equal? E2 E1)])
	    (cond 
	     [(and (null? u1) (null? u2) ) '()]
	     [( = (length u1) 1) 
	      (if ( = (length u2) 1)
		  (list (cons (car u1) (car u2)))
		  (list (cons (car u1) (cons Union u2))))]
	     [else
	      (for*/list
	       ([i u1]
		[j u2]
		;:when (pselect? i j)
		)
	       (loop i j)
	       )]))]

	 ;[`((,(? union-symbol? U) ,E1 ...)(,E2 ...))	  ]

	 [else
	  (append (loop (car lst1) (car lst2))
		  (loop (cdr lst1) (cdr lst2)))]
	 )
	]
))))
		
;; (union-types-difference-correspond `(1 2) `(1 3)) ;;'((2 . 3))
;; (union-types-difference-correspond `(1 2 (a b))  `(1 3 (10 11)))
;; (union-types-difference-correspond `(,Union 1 2 a c)  `(,Union b d 2 1))
;; (union-types-difference-correspond `(,Union 1 2 a)  `(,Union b d 2 1))
;; (union-types-difference-correspond `(list (,Union 1 2 a) x)  `(list (,Union b d 2 1) y) )



(define (env-type-match-partial-specialization args-types args-specialization-types env-match [unknown-typed-list null] [rel-constraints-init null])
  (display (list 'env-type-match-partial-specialization args-types args-specialization-types env-match unknown-typed-list rel-constraints-init ))(newline)
  (let-values([
	       (env-rel
		rel-constraints1
		rel-var-alist
		env-rel-var
		)
	       (type-env-match->type-env-rel-var--constraints--rel-var-alist env-match unknown-typed-list rel-constraints-init)
	       ])
    (let* (
	  ;[args-types (map (curryr var-env->direct-type env-match) args)]
	  [args-rel-types (map (curryr var-env->direct-type env-rel) args-types)]
	  ;[args-types
	  ;)
	  ;; [rel-constraints 
      	  ;;   (cons
      	  ;;    (
	  ;;     ;== 
	  ;;     +== 
	  ;;     args-rel-types args-specialization-types
	  ;;     )
      	  ;;    rel-constraints1)]
	  [rel-constraints 
	   (append
	    (type-list-+==->condition-list args-rel-types args-specialization-types)
      	     rel-constraints1)]
	  
	  [ret-env-type-rel-result	 
	   (run* (q)
	    (for-kanren  (reverse rel-constraints))
	    (== q (cons args-rel-types env-rel))
	    ;(== q args-rel-types)
	    )
	   ]
	  
	  )
     (display (list rel-var-alist args-rel-types ret-env-type-rel-result)) (newline)
     ;(display (list env-rel-var)) (newline)

      ;;ret-env-type-rel-result
    ;; (values
    ;;  env-rel
    ;;  rel-constraints   
    ;;  )
    (let-values ([
		  (env-union-match
		   ret-union-match
		   unknown-typed-list-total)
		  (type-ret-env-rel-list->union-env--unon-ret--unknown-typed-list ret-env-type-rel-result)  
		  ])
      (display (list env-match env-union-match)) (newline)
      (values
       (remove-duplicates (union-types-difference-correspond env-match env-union-match unknown-typed-list ))
       env-union-match
       unknown-typed-list-total)
      )
       
    )
))


;; (env-type-match-partial-specialization
;;  '() '() 
;;  `( (y . (,Union x ,Number))  (x . (,Union x ,Int) ))
;; )


;; (env-type-match-partial-specialization
;;  '(x) (list Char) 
;;  `( (y . (,Union x ,Number))  (x . (,Union x ,Int) ))
;; )

;; > '((x . Char221))
;; '((y Union217 Char221 Number201) (x Union217 Char221 Int203))
;; '()



;; (env-type-match-partial-specialization
;;  '(x) (list Char) 
;;  `( (y . (,Union y ,Number))  (x . (,Union x ,Int) ))
;; )


;; > '((x . Char221))
;; '((y Union217 y Number201) (x Union217 Char221 Int203))
;; '(y)
;; > 


;; (env-type-match-partial-specialization
;;  '(x y) (list Char Int) 
;;  `( (y . (,Union y ,Number))  (x . (,Union x ,Int) ))
;; )

;; > '((Number201 . Int203))
;; '((y Union217 y Int203) (x Union217 Int203 x Char221))
;; '(y x)
;; > 




;; (env-type-match-partial-specialization
;;  '(x y) '(z Int) 
;;  `( (y . y )  (x . x ))
;; )

;; > '((y . Int) (x . z))
;; '((y . Int) (x . z))
;; '()


;; (env-type-match-partial-specialization
;;  '(x y) '(z Int) 
;;  `( (y . y )  (x . x ))
;; )



;; (env-type-match-partial-specialization
;;  '(x) (list Char) 
;;  `( (x . (,Union x ,Int) ))
;; )


;; (env-type-match-partial-specialization
;;  '(x) (list Double) 
;;  `( (x . (,Union x ,Int) ))
;; )



;; ;;;;; bug
;; (env-type-match-partial-specialization
;;  '(x y) (list 'z Int) 
;;  `( (y ,Union y ,Int )  (x . x ))
;; )

;; ;;;;; bug
;; (env-type-match-partial-specialization
;;  '(x y) (list 'z 'Int) 
;;  `( (y ,Union y ,Int )  (x . x ))
;; )
;; > '((y . Int) (x Union754 x z))
;; '((y Union754 Int Int740) (x Union754 x z)) ;;!!!! bug should be (x  . z )
;; '(x)
;; > 

;; 
;; (env-type-match-partial-specialization 
;;  `((Union965 guess2 Double954) (Union965 x3 Double954)) 
;;  `(Double954 Double954) 
;;  `((x5 . Double954) (y Union965 x3 guess2 Double954) (x4 Union965 guess2 Double954) (x3 Union965 x3 Double954) (guess2 Union965 guess2 Double954) (x2 . Double954) (guess1 . Double954) (x1 . Double954) (guess . Double954) (x . Double954) (main lambda () Int951) (square lambda (Double954) Double954) (average lambda ((Union965 guess2 Double954) (Union965 x3 guess2 Double954)) (Union965 guess2 x3 Double954)) (improve lambda ((Union965 guess2 Double954) (Union965 x3 Double954)) (Union965 guess2 x3 Double954)) (good-enough? lambda (Double954 Double954) Bool964) (sqrt-iter-double lambda (Double954 Double954) Double954) (sqrt-double lambda (Double954) Double954))
;; )


;; (env-type-match-partial-specialization 
;;  `((Union965 guess2 Double954) (Union965 x3 Double954)) 
;;  `(Double954 Double954) 
;;  `((x5 . Double954) (y Union965 x3 guess2 Double954) (x4 Union965 guess2 Double954) (x3 Union965 x3 Double954) (guess2 Union965 guess2 Double954) (x2 . Double954) (guess1 . Double954) (x1 . Double954) (guess . Double954) (x . Double954) (main lambda () Int951) (square lambda (Double954) Double954) (average lambda ((Union965 guess2 Double954) (Union965 x3 guess2 Double954)) (Union965 guess2 x3 Double954)) (improve lambda ((Union965 guess2 Double954) (Union965 x3 Double954)) (Union965 guess2 x3 Double954)) (good-enough? lambda (Double954 Double954) Bool964) (sqrt-iter-double lambda (Double954 Double954) Double954) (sqrt-double lambda (Double954) Double954))
;; )


;; ;; f-free-type-variable-bind-free-alist


;; (define (function-specialize-type fname
;; 	 args-types 
;; 	 args-specialization-types 

;; 	 function-free-type-variable-bind-free-alist

;; 	 env-match 
;; 	 [unknown-typed-list null] 
;; 	 [rel-constraints-init null])


;;   (env-type-match-partial-specialization 
;; 	 args-types 
;; 	 args-specialization-types 
;; 	 env-match 
;; 	 unknown-typed-list
;; 	 rel-constraints-init)


;; ;; (define (env-type-match-partial-specialization 
;; ;; 	 args-types 
;; ;; 	 args-specialization-types 
;; ;; 	 env-match 
;; ;; 	 [unknown-typed-list null] 
;; ;; 	 [rel-constraints-init null])




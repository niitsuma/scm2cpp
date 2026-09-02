#lang racket

(provide 
 op-float->float 
 op-num->num 
 op-num-num->num
 op-num-num-num   ;
 op-num-num->num
 op-int->bool
 op-num->bool
 op-num-num->bool
 op-num-num-bool  ;
 op-any-any->bool
 op-any->bool
 op-str->str
 op-str-str ;
 op-lambda->bool-vector
 op-lambda->bool-list 
 op-lambda->bool
 op-lambda-vector
 op-lambda-list
 op-lambda ;??
 op-any-lambda->bool
 op-any-lambda-vector
 op-any-lambda-list
 op-any-lambda ;
 op-any-any-lambda

 uvect-types
 scheme-primitives
 scheme-primitive?

 not-scheme-primitive?

 ;compiler-tags 
 constant?

 not-else-symbol?
 not-terminal-statement? 

 symbol-envs->gensym 

 var-envs2gensym

 ;primitives 
 ;primitives?  
 alpha-conv
 alphac
 unalphac
 envinvert 
 env-rename
 env2-rename
 testalphac

 ;expr-lambda-name

 lambda-expr?
 lambda-and-wrap-expr?


 pre-alpha-expr-mod

)

(require "list-util.scm")
(require "cl-util.scm")

;(require srfi/1)
;(require mzlib/defmacro)
;

(define op-float->float '(sin cos tan exp log acos asin atan sqrt))
(define op-num->num '(sub1 add1))
(define op-num-num->num  '(+ - * / remainder quotient max min abs power))
(define op-num-num-num op-num-num->num)
(define op-int->bool '(even? odd?))
(define op-num->bool '(zero? positive? negative? exact? inexact?  even? odd?))
(define op-num-num->bool (append op-num->bool '( =  >  <  <= >= )))
(define op-num-num-bool op-num-num->bool)
(define op-any-any->bool '(eq? equal? eqv?))
(define op-any->bool '(null? pair? list? vector? number? symbol?  real? exact-integer? integer? inexact? exact? string? boolean? char? ))
(define op-str->str  '(string-append ))
(define op-str-str op-str->str)
(define op-lambda->bool-vector '(vector-filter vector-filter-not vector-count))
(define op-lambda->bool-list '(filter memf findf assf count partition filter-not))
(define op-lambda->bool (append op-lambda->bool-vector op-lambda->bool-list))  
(define op-lambda-vector '(vector-map vector-map! vector-argmin vector-argmax))
(define op-lambda-list '(apply map fold foldl foldr for-each andmap ormap filter-map  append-map argmin argmax))
(define op-lambda (append op-lambda->bool op-lambda-vector op-lambda-list))
(define op-any-lambda->bool '(sort))
(define op-any-lambda-vector '(build-vector))
(define op-any-lambda-list '(build-list sort))
(define op-any-lambda (append op-any-lambda->bool op-any-lambda-vector op-any-lambda-list
'(with-output-to-file with-input-from-file call-with-input-file call-with-output-file call-with-input-string call-with-output-string
)
))
(define op-any-any-lambda
  '(remove remove*  ;;apply lam->bool
))

(define (op-lambda? o) (member op-lambda))
(define (op-any-lambda? o) (member op-any-lambda))
(define (op-any-any-lambda? o) (member op-any-any-lambda))

(define uvect-types
'( 
s8vector	;signed exact integer in the range -(2^7) to (2^7)-1
u8vector	;unsigned exact integer in the range 0 to (2^8)-1
s16vector	;signed exact integer in the range -(2^15) to (2^15)-1
u16vector	;unsigned exact integer in the range 0 to (2^16)-1
s32vector	;signed exact integer in the range -(2^31) to (2^31)-1
u32vector	;unsigned exact integer in the range 0 to (2^32)-1
s64vector	;signed exact integer in the range -(2^63) to (2^63)-1
u64vector	;unsigned exact integer in the range 0 to (2^64)-1
;There are 2 datatypes of inexact real homogeneous vectors (which will be called float vectors):
;datatype	type of elements
f32vector	;inexact real
f64vector	;inexact real
))



(define scheme-primitives
  (
   ;lset-union 
   ;equal?
   append 
   op-float->float 
   op-num-num->num
   op-num-num->bool
   op-any-any->bool
   op-any->bool
   op-str->str
   op-lambda
   op-any-lambda
   op-any-any-lambda
   '(  
       and or not
       quote
       
       compose

       display newline 
       define lambda curry curryr case-lambda 
       let let* letrec letrec* let-values let*-values define-values call-with-values 
       begin set! 

       values struct
       
       list make-list list-ref append null list-tail reverse length
       take last drop take-right drop-right
       cons car cdr set-car! set-cdr! 
       
       mamber memq
       assoc assv assq
       
       
       
       
       ;;zero?


       vector vector-ref vector-set!  make-vector vector-length
       vector-copy floor inexact->exact
       ;; The promise forms. Missing here, a force inside a lambda was
       ;; a free variable of that lambda: captured as a member of unknown
       ;; type, and the type of the forced value never reached inference.
       delay force make-promise
       if else when unless cond case 
       do
       call/cc call-with-current-continuation
       string
       string->symbol symbol->string

       
       max min


       ;=>
       quotient/remainder

       open-input-file
       read-char
       eof-object?
       close-input-port

    )
   uvect-types)
  )

(define (scheme-primitive? op)
  (and (symbol? op)
       (memq op scheme-primitives)))

(define  (not-scheme-primitive? op) (not (scheme-primitive? op)))


;; (define compiler-tags 
;;   '(string
;;     char short int float double
;;     port 

;;     unknown 
;;     no-type
;;     expand-type
;;     sexpr
;;     type-match-fail
;;     inf
;;     inf-alist
;;     union
;;     subst ref
    

;;     ;;Homogeneous vector	      
;;     homo-vector homo-vector-fix-length homo-list homo-list-fix-length
;;     bool-vector bool-vector-fix-length
;;     homo-alist homo-alist-fix-length
;;     alist alist-fix-length
    
;;     lambda-export
;;     )
;;   )


(define (constant? c)
  (match c
   (`(quote ,x)   #t)
   ( (? number? ) #t)
   ( (? string? ) #t)
   ( (? boolean?) #t)
   ( (? char? ) #t)
   ( _ #f)
   )
  )
;;;debug 
;; (constant? '(+ a b))
;; (constant? ''a)


(define (not-else-symbol? expr)  (not (eq? expr 'else)))


(define (not-terminal-statement? expr)
  (match 
   expr
   [`(when ,E1 ,E2) true]
   [`(unless ,E1 ,E2) true]
   [`(cond (,(? not-else-symbol? P)  ,E ...) ... ) true] 
   [`(case ,E1 (,(? not-else-symbol? P) ,E ...  )  ...) true]
   [_ false]))
   
;; (not-terminal-statment? '(when (= x y) 2 ))
;; (not-terminal-statment? '(cond (= x y) 2 ))
;; (not-terminal-statment? 
;;  '(cond
;;    ((or (<= age 3) (>= age 65)) 0)
;;    ((<= 4 age 6) 50)
;;    ((<= 7 age 12) 100)
;;    ((<= 13 age 15) 150)
;;    ((<= 16 age 18) 180)
;;    (else 200)))
;; (not-terminal-statment? 
;;  '(cond
;;    ((or (<= age 3) (>= age 65)) 0)
;;    ((<= 4 age 6) 50)
;;    ((<= 7 age 12) 100)
;;    ((<= 13 age 15) 150)
;;    ((<= 16 age 18) 180)
;;    ))


(define (symbol-contain-?-replace s)
  ;(let ([st 
  (string->symbol
   ;; (list->string
   ;;  (map
   ;;   (lambda (x) (if (equal? #\? x) #\-  x))
   ;;   (string->list

   (regexp-replace 
    "\\?" 
    (symbol->string  s)
    "-questionmark-")

))

;(symbol-contain-?-replace 'average?)

(define (invalid-symbol-name-correct s)
  ;(symbol-contain-?-replace s)
  s
  )
			  		  
;; (regexp-replace "\\?" "mi?casa" "--")
;; (regexp-replace "mi" "mi ? casa" "su")
;; (regexp-replace "mi" "mi casa" "su")

;;;----------------------------------------------------------------------------



;; Alpha-conversion. 
(define (symbol-envs->gensym v env-list [k 1])
  ;(display (list v k env-list))(newline)
  (let ([g
	 (string->symbol
	  (string-append
	   (symbol->string v)
	   ;; A single character overflows past 9 into ':' ';' '<' -- the
	   ;; QAP core has eleven loops over a and produced identifiers no
	   ;; C++ compiler accepts. Decimal keeps every suffix legal.
	   (number->string k)
	   ))
	 ])
    (if (null? env-list)
	g
	(if (assq g (car env-list))
	    (begin
	      (set! k (+ 1 k))
	      (symbol-envs->gensym v env-list k)
	      )
	    (symbol-envs->gensym v (cdr env-list) k)
	    ))))
	    
	
;; (symbol-envs->gensym 'k '(((x . x ) (y . y) ) ((u . u ) (v . v) )  ((a . a ) (b . b) )   ))
;; => k1
;; (symbol-envs->gensym 'b '(((x . x ) (y . y) ) ((u . u ) (v . v) )  ((a . a ) (b . b) )   ))
;; => b1
;; (symbol-envs->gensym 'b '(((x . x ) (b1 . b) ) ((u . u ) (v . v) )  ((a . a ) (b2 . b) )   ))
;; => b3


  
 

(define (var-env2gensym v env) (cond ((assq v env) (gensym v))(else v)))
(define (var-envs2gensym-old v env-list) 
  (if (null? env-list) v
      (if (assq v (car env-list))  (gensym v)
	  (var-envs2gensym v (cdr env-list))))) 

(define (var-envs2gensym v env-list-total)
  (let ([env-rev-list (map (lambda (l) (map cons-reverse l)) env-list-total)])
  (let loop ([v v] [env-list env-list-total])
    (if (null? env-list) v
	(if (assq v (car env-list))  
	    ;(gensym v)
	    (symbol-envs->gensym v env-rev-list)
	    (loop v (cdr env-list))))))) 


;; (var-envs2gensym 'k '(((x . x ) (y . y) ) ((u . u ) (v . v) )  ((a . a ) (b . b) )   ))
;; =>k
;; (var-envs2gensym 'b '(((x . x ) (y . y) ) ((u . u ) (v . v) )  ((a . a ) (b . b) )   ))
;; => b1
;; (var-envs2gensym 'b '(((b . b ) (b1 . b) ) ((u . u ) (v . v) )  ((a . a ) (b2 . b) )   ))
;; ;=> b3



(define (alpha-conv expr)  
 (let ([env (match expr
  [`(define ,(? symbol? v) ,E1) `((,v . ,v))]
  [`(define ,params ,E ...) (let ([f (car params)])`((,f . ,f)))]
  [`(define-values (,id ...) ,B) (map cons id id)]
  [ _ '() ] )])
   ;(display env)(newline)
   (let-values 
       ([(oex oev ofv oav) (alphac expr env '() 
				    ;; ;; scheme-primitives
				    ;; (map (lambda (x) (cons x x)) (append scheme-primitives compiler-tags ))
				    '())])
     (let* ([oev1 (append oav oev)]
	    [invalid-rename-alist '()]
	    [all-new-name-list (append (map cdr oev1) (map cdr ofv))]
	    [kv-update-invalid-rename-alist
	     (lambda (kv)
	       (let* (
		      [v0 (car kv)]
		      [v1 (cdr kv)]
		      [v2  (invalid-symbol-name-correct v1)]
		      [v3  (if (eq? v1 v2) v2
			       (if (member v2 all-new-name-list)
				   (gensym v2) v2
				   ))]
		      )
		 (unless (equal? v1 v3)
			 (lstack-push!
			  (cons v1 v3) 
			  invalid-rename-alist))
		 ;(display (list v0 v1 v2 v3 (equal? v1 v3)))(newline)
		 ))]
	    )
       (for-each kv-update-invalid-rename-alist	oev1)
       (for-each kv-update-invalid-rename-alist	ofv)
       ;(display (list invalid-rename-alist all-new-name-list  oex oev1 ofv) )(newline)       
       ;(values oex oev1 ofv)
       (values 
	(cl:sublis invalid-rename-alist oex) 
	(map (lambda (kv ) (cons (car kv) ( cl:sublis invalid-rename-alist (cdr kv)))) oev1) 
	(map (lambda (kv ) (cons (car kv) ( cl:sublis invalid-rename-alist (cdr kv)))) ofv)
	)
      ))))

(define (alphac expr env freev env-apend-after)
  ;; (define env-apend-after null) ;;not in current scove var env
  (define (addedenv add-env) (append add-env env))
  (define (envup add-env) (set! env (append add-env env)))
  (define (freeup add-env) (set! freev (append add-env freev)))
  (define (apend-after-up add-env) (set! env-apend-after (append add-env env-apend-after)))
  (define (var-gen var) (var-envs2gensym var (list env freev env-apend-after)))
  (define (var-gen-cons var) (cons var (var-gen var))) 
  (define (var-gen-single-env var) (list (var-gen-cons var))) 
  (define (freeup-var var)    (freeup (var-gen-single-env var))     (cdar freev ))
  (define (envup-var var)    (envup (var-gen-single-env var))     (cdar env ))
  (define (rename v)
    (cond ((assq v env) => cdr)
	  ((assq v freev) => cdr)
	  ;((assq v env-apend-after) => cdr) ;;;;;bug no include
	  (else (freeup-var v) )))
  (define (ace ex ev)  (let-values ([(oex oev ofv oav) (alphac ex ev freev env-apend-after)]) ;;add sub tree env to current env
      (set! env oev) (set! freev ofv) (set! env-apend-after oav)  oex)) 
  (define (ac e) (ace e env)) ;ac=alpha-conv simple
  (define (acea ex ev) (let-values ([(oex oev ofv oav) (alphac ex ev freev env-apend-after)]) ;;add sub tree env to after current scope env
    (let* ([ev-deff (remove* ev oev)] ;;ev = previous env before call alphac
	   [av-deff (remove* env-apend-after oav)]
	   [av-new (append av-deff ev-deff env-apend-after)]
	   )
      ;(display (list 'acea  oex oev ofv oav ev-deff av-deff))(newline)		 
      ;; (set! env-apend-after  (append (remove* ev oev) oav )) 
      (set! env-apend-after av-new) ;;ev = previous env before call alphac
      (set! freev ofv)
      ;(display (list 'acea2  env freev env-apend-after ev))(newline)
      oex)))
  (define (aca e) (acea e env))
  (define (fresh-params-env params) (map var-gen-cons params))
  (define (fresh-vars-env bindings) (map (lambda (b) (var-gen-cons (car b))) bindings))
  
  ;; (define (lambda-flattened-args-update params) 
  ;;   (let [fresh-params (fresh-params-env params)]
  ;; 	(envup (reverse fresh-params))
  ;; 	(map cdr fresh-params) ))
  (define (lambda-args-update params)
    (let ([fresh-params-rev-env (fresh-params-env (reverse (flatten params)))])
      ;(display fresh-params-rev-env)(newline)
      (envup fresh-params-rev-env)
      ;(apend-after-up fresh-params-rev-env)
      ;(display env)(newline)
      (map-tree rename params)))
    ;; (let ([e (last-pair params)])
    ;;  (if (pair? e)
    ;;   (let* ([params2
    ;; 	      (lambda-flattened-args-update
    ;; 	       (append (drop-right params 1) `(,(car e) ,(cdr e))))]
    ;; 	     [e1 (take-right params2 2)]
    ;; 	     [e2 (cons (car e1) (cadr e1))])
    ;; 	(append (drop-right  params 2) e2))        
    ;;   (lambda-flattened-args-update params)))) 

  (define (define-function-return params E)
    ;(display (list 'define-function-return params E))(newline)
    (let* ([fname (rename (car params))]
	   [args (cdr params)]
	   ;[fresh-params (fresh-params-env (cdr params))]
	   [fname1 (rename fname)]
	   [args1 (lambda-args-update args)]
	   )
	;(envup (reverse fresh-params))
	`(define (
		  ;; ,(rename fname) 
		  ,fname1
		  . 
		  ;; ;; ,(map cdr fresh-params) 
		  ;; ,(lambda-args-update args)
		  ,args1
		  )
		,@(aec-body E))))
  (define (lambda-type-return type params E)
    (let* ([fresh-params (fresh-params-env params)])
	   ;;(new-env (addedenv fresh-params))
	;(envup (reverse fresh-params))
	;; (display (list 'lambda-type-return type fresh-params `(,type ,(map cdr fresh-params)))) (newline)
	`(,type
	  ,(lambda-args-update params)
	  ;,(map cdr fresh-params)
	  ,@(aec-body E))))
  (define (define-symbol-return  v E1)
      (let* ((fresh-params  (var-gen-single-env v)))
	(envup fresh-params)
	`(define ,(cdar fresh-params) ,(aca E1))))
  (define (define-values-return id B)
    (let* ((fresh-params (fresh-params-env id)))
      (envup (reverse fresh-params))
      `(define-values ,(map cdr fresh-params) ,(aca B))))
  (define (aec-body exprs)
    ;(display (list 'aec-bosy exprs env freev env-apend-after))(newline) 
    ;(display (list 'aec-bosy exprs))(newline) 

    ;;;;; update define
    (for-each (lambda (e) (match e
    	[`(define ,(? symbol? v) ,E1) (envup (var-gen-single-env v))]
    	[`(define ,params ,E ...)   (envup (var-gen-single-env (car params)))]
    	[`(define-values (,id ...) ,B) (envup (reverse (fresh-params-env id)))]
	[ _ null ]
    	))   	 exprs)

    (map (lambda (e) (match e 
	[`(define ,(? symbol? v) ,E1)  
	 ;(define-symbol-return  v E1)
	 `(define ,(rename v) ,(aca E1))
	 ]
	[`(define ,params ,E ... )
	 ;(set! env (remove (assq (car params) env) env));;remove curerent  f name from current env
	 ;(display (list (assq (car params) env) env))(newline)
	 (let* ((ret (aca e))
		;(defcons (assq (car params) env-apend-after)) ;func name add after
		;(defenv  (list defcons))
		)
           ;(display (list 'aec-bosy2 defenv defcons env-apend-after))(newline) 
	   ;(envup defenv);;;aleady current envup in update define
	   ;(set! env-apend-after  (remove defcons  env-apend-after))
	   ret)]
	[`(define-values (,id ...) ,B) 
	 ;(define-values-return id B)
	 `(define-values ,(map rename id) ,(aca B))
	 ]
	[ _ (aca e)]
	))
	 exprs)
    )
  (define (aec expr)    
    ;(display (list 'aec expr))
    (match      expr	        

     (`(quote ,x)	    expr)
     ;(`(quote ,x)	    `(quote ,(ac x)))

     ((? constant? c) expr)

     ;[(? symbol?)	    (rename expr)]
     [(? symbol?)
      ;(when (and (assq expr env) (scheme-primitive? expr)) (envup  (list (cons expr  (gensym expr)))))
      ;(display env)
      (rename expr)]

     (`(set! ,v ,E1)	    `(set! ,(rename v) , (ac E1)))
     (`(begin ,E ...) `(begin ,@(aec-body E)))
     [`(define ,(? symbol? v) ,E1)  
      ;(define-symbol-return  v E1)) ;;need eval oder after E1 then v envup
      `(define ,(rename v) ,(ac E1))
      ]
     [`(define-values (,id ...) ,B) 
      ;(define-values-return id B)
      `(define-values ,(map rename id) ,(ac B))
      ]
     [`(define ,params ,E ... )
      ;;(lambda-type-return 'define params E)
      ;;(envup (var-gen-single-env (car params)))
      (define-function-return params E)
      ;; (let ([vars (cdr params)][f (car params)])`(define (,(rename f) cdar fresh-params) ,(ac E)))))
      ]
     [`(lambda ,params ,E ... ) 
      (lambda-type-return 'lambda params E)]
     [`(let ,(? symbol? v) ,bindings ,E ... )  ;;named let
      ;;(display (list 'named-let-alpha v bindings E))(newline)
      (let* ((fresh-params  (var-gen-single-env v))
	     (fresh-vars (fresh-vars-env bindings)))
	(envup fresh-params) (envup fresh-vars)
	`(let ,(cdar fresh-params)
	   ,(map (lambda (v e) `(,(cdr v) ,(aca (cadr e))))
		    fresh-vars  bindings)
	   ,@(aec-body E)))]
     ;; (`(let ,bindings ,E ... )
     ;;  (let* ((fresh-vars (fresh-vars-env bindings)))
     ;; 	(envup fresh-vars)
     ;; 	`(let ,(map (lambda (v e) `(,(cdr v) ,(aca (cadr e))))
     ;; 		    fresh-vars  bindings)
     ;; 	   ,@(aec-body E))))
     [`(let ((,X ,V) ... ) ,E ... )
      (let* ((vs (map aca V))
	     (xs (map envup-var X)))
	`(let ,(map list xs vs)
	   ,@(aec-body E)))]
     [`(let* ((,X ,V) ... ) ,E ... )
      (let ((xvs (map (lambda (x v) 
			(let* ((vv  (aca v )) 
			       (xx (envup-var x)))
			  (list xx vv)))
			X V )))
	`(let* ,xvs ,@(aec-body E)))]
     ;; [`(let* ,E ... ) (ac `(let . ,E)) ] 
     [`(letrec ((,X ,V) ... ) ,E ... )
      (let* ((xs (map envup-var X))
	     (vs (map aca V)))
	`(letrec ,(map list xs vs)
	   ,@(aec-body E)))]
     [`(letrec* ,E ... ) (ac `(letrec . ,E)) ] 
     ;; The termination clause is (test result ...), and the result may be
     ;; absent -- ((= i n)) is the ordinary shape for a loop run for effect.
     ;; A two-element pattern did not match it, so the whole form fell
     ;; through to the generic walk and the loop variables were never bound:
     ;; they escaped as free variables, and a lambda enclosing such a loop
     ;; tried to capture them.
     [`(do  ((,X ,V ,N) ...) (,L ,R ...) ,E ... )
      (let* ((vs (map aca V))
	     (xs (map envup-var X))
	     (ns (map aca N))
	     (ls (aca L))
	     (es (aec-body E))
	     (rs (map aca R))
	     )
     	`(do ,(map list xs vs ns) (,ls ,@rs) ,@es))]
     ;; [`(do  ,bindings ,pred ,E ... )
     ;;  (let* ((fresh-vars (fresh-vars-env bindings)))
     ;; 	(envup fresh-vars)
     ;; 	`(do ,(map (lambda (v e) `(,(cdr v) ,(aca (cadr e)) ,(aca (caddr e))))
     ;; 		    fresh-vars  bindings)
     ;; 	     ,(map aca pred)
     ;; 	   ,@(aec-body E)))]
     [`(let-values ([(,id ...) ,val-expr] ...) ,body ...)      
      (let* ((vs (map aca val-expr))
	     (xs (map (lambda (x) (map envup-var x)) id)))
	`(let-values ,(map list xs vs)
	   ,@(aec-body body)))]
     [`(let-values* ([(,id ...) ,val-expr] ...) ,body ...)      
      (let ((xvs (map (lambda (x v) 
			(let* ((vv  (aca v )) 
			       (xx (map envup-var x)))
			  (list xx vv)))
			id val-expr )))
	`(let* ,xvs ,@(aec-body body)))]


     (`(if     ,E1 ,E2 ,E3)	    `(if ,(aca E1) ,(aca E2) ,(ac E3)))
     ;(`(if ,E1 ,E2)	    `(if   ,(aca E1) ,(ac E2)))
     (`(if     ,E1 ,E2)	    `(when ,(aca E1) ,(ac E2)))
     (`(when   ,E1 ,E2)	    `(when ,(aca E1) ,(ac E2)))
     (`(unless ,E1 ,E2)	    `(unless ,(aca E1) ,(ac E2)))
     [`(cond ,E ...)
      (let* ([clauses (drop-right E 1)][last-clause (last E)] )
	 `(cond ,@(map 
		   (lambda (x) 
		     (match
		      x
		      [`(,T => ,B)
		       `(,(aca T) => ,(if (scheme-primitive? B) B (aca B)))]
		      [`(,T) `(,(aca T))]
		      [`(else ,B ...) `(else ,(car (cdr (aca `(begin . ,B)))))]
		      [ _
		       (cdr (aca `(begin . ,x)))
		       ]
		      ))
		   ;clauses 
		   E
		   ) 
		;; ,(match last-clause 
		;; 	[`(else ,E1 ... ) 
		;; 	 `(else . ,(aec-body E1))] 
		;; 	[ _ (aec-body last-clause)])
		)
	 )
      ]
     [`(case ,E1 ,E ...) ;; (display (list 'case-alpha E))(newline)
      `(case ,(aca E1)
           ,@(map (lambda (x) ;; (display x)(newline)
		      (cons (match (car x)  
				   ['else  'else] 
				   [_ (map aca (car x))]) 
			    (cdr (aca `(begin . ,(cdr x)))))) E )) ]
     (`(,E0 . ,Es)
      `(,(if (scheme-primitive? E0) E0 (aca E0))
	,@(map aca Es)))
     (_      
      (error "unknown-expression in aplha" expr)
      (list 'unknown_expression expr)
      )
     )
    ) 
  ;; (values (aec expr) (append env-apend-after env) freev)
  (let ((oex (aec expr)))
    ;; (display (list oex env freev env-apend-after)) (newline)
    (values oex env freev env-apend-after))
  )

;;;;;;;;;

;; (alpha-conv 
;; '
;; (begin 
;;   (set! x 3)
;;   (let* ((x 20))
;;     (let* ((a (let* ((x 10)) (+ x 3))))
;;       (set! x 2))
;; )))

;; (alpha-conv '(do ((n1 n (- n1 1)) (p n (* p (- n1 1)))) ((= n1 1) p)))

;;;----------------------------------------------------------------------------

(define (unalphac expr env)
  (define (uac e) (unalphac e env))
  (define (rename v)    (cond ((assq v env) => cdr)          (else v)))
  (match 
   expr	   
   ((? constant? c) expr)

   (`(quote ,x)	    expr)
   ;(`(quote ,x)   `(quote ,(uac x)))

   ((? symbol?)	    (rename expr))
   (`(set! ,v ,E1)	    `(set! ,(rename v) , (uac E1)))
   (`(begin ,E ...) `(begin ,@(map uac E)))
   (`(define ,(? symbol? v) ,E1)  `(define ,(rename v) ,(uac E1)))
   (`(define ,params ,E ... ) `(define ,(map rename params) ,@(map uac E)))
   (`(lambda ,params ,E ... ) `(lambda ,(map rename params) ,@(map uac E)))
   (`(let ,(? symbol? v) ,bindings ,E ... )  ;;named let
    `(let  ,(rename v) ,(map (lambda (e) `(,(rename (car e)) ,(uac (cadr e))))
		bindings)
       ,@(map uac E)))
   (`(let ,bindings ,E ... )
    `(let ,(map (lambda (e) `(,(rename (car e)) ,(uac (cadr e))))
		bindings)
       ,@(map uac E)))
   (`(when ,E1 ,E2)	    `(when ,(uac E1) ,(uac E2)))
   (`(if ,E1 ,E2)	    `(if ,(uac E1) ,(uac E2)))
   (`(if ,E1 ,E2 ,E3)	    `(if ,(uac E1) ,(uac E2) ,(uac E3)))
   (`(,E0 . ,Es)  
    `(,(if (scheme-primitive? E0) E0 (uac E0))
      ,@(map uac Es)))
   (_      (error "unknown expression" expr)))
  )

(define (envinvert env)
  (map (lambda (e) (cons (cdr e) (car e))) env))

;; (unalphac '(let ((x 10 )  ) (+ 10 x )) '((x . X)  (y . Y  )))
;; (unalphac '() '((x . X)  (y . Y  )))
;; (envinvert '((x . X)  (y . Y  )))

(define (env-rename v env)    (cond ((assq v env) => cdr)  (else v)))
(define (env2-rename v env-inv-alpha env-inv-free)
  (cond 
   ((assq v env-inv-alpha) => cdr)
   (else 
    (cond 
     ((assq v env-inv-free) => cdr)
      (else v
	    )))))
;;;;;usage 
;; (define expr '(define (f x y ) (display x) (display y) (+ x y )))
;; (let-values ([(expr-aplha env-alpha env-free)     (alpha-conv expr)])
;;   (display env-alpha)(newline)
;;   (let ((v (cdr (car env-alpha))))
;;     (display v) (newline)
;;     (display (env2-rename v (envinvert env-alpha) ( envinvert env-free)))
;;   ))


;;;----------------------------------------------------------------------------

(define (testalphac expr)
 (let-values ([(ex ev fv)     (alpha-conv expr)])
   (let* (
	 (exi0 (unalphac ex (envinvert ev)))
	 (exi (unalphac exi0 (envinvert fv)))
	 ) 
	 ;(display expr)(newline)
	 ;(display exi)
	 (if (not (equal? expr  exi))	 
	     (list expr exi ex ev) 
	     #f) )))  ;;;corect result = #f

;; (alpha-conv
;;  '(define (f y) 
;;     (let ((z (lambda (x y) (+ x y))) )
;;     (lambda (u v)  (+ u v))
;;     ;0
;;     )))

;; (alpha-conv '(let ((z (lambda (x127 y128) (+ x127 y128)))) (lambda (u v) x (+ u v))))

;; (require "list-util.scm")
;; (define tmp-exp (s-read "fft.sc"))
;; (set! tmp-exp (cons 'begin tmp-exp))
;; (alpha-conv tmp-exp)



(define (expr-lambda-name expr)
  (define lambda-names '())
  (define (rn expr)
    (match
     expr
     [`(lambda ,params ,E ... )
      (let ((lname (gensym 'lambda)))
	(set! lambda-names (cons lname lambda-names))
	;`(let
	`(letrec
	     ((,lname ,`(lambda ,params . ,E)))
	   ,lname))]
     [ (? pair?) 
       (map rn expr)]
     [ _ expr]
     ))
  (let ((r (rn expr)))
    (values r lambda-names)))
  
  

;; (expr-lambda-name 
;;  '(begin
;;     (display 1)
;;     (lambda (x) x)
;;     ( (lambda (x y) (+ x y))
;;     2 3)
;;     )
;; )
;; (begin
;;    (display 1)(newline)
;;    (let ((lambda869 (lambda (x) x))) lambda869)
;;    ((letrec ((lambda870 (lambda (x y) (+ x y)))) lambda870) 2 3))

;; ;(begin (display 1) ((let ((lambda36 (lambda (x y) (+ x y)))) lambda36) 2 3))
;; (expr-lambda-name  '(lambda (x y) (+ x y) (- x y )))
;; (expr-lambda-name  '(lambda (x y) (+ x y) ))




(define (extract-main expr)
  (define main-expr '())
  (define (mod-top ex)
    (match 
     ex
     ;['begin #t]
     [`(define (main . ,X) ,E ...)
      (set! main-expr (append (reverse E ) main-expr))
      #f]     
     [ `(define ,E ...) #t]
     [ `(define-values ,E ...) #t]
     [ `(define-record-type ,E ...) #t]
     [ _ (set! main-expr (cons ex main-expr)) #f]))
  (let* ([expr1
	  ;(if (= (length expr) 1)
	  ;    expr
	 (match 
	  expr
	  [`(begin ,E ...) E]
	  [ _ expr])]
	 [body (filter mod-top expr1)]
	 [body2 
	  (if (null? main-expr)
	      body
	      (append body
		      `((define (main) (begin ,@(reverse main-expr) 0)))))])
    ;(display (list expr1 body body2))(newline)
	`(begin . ,body2)))



(define (lambda-expr? expr)
  (match
   expr
   [`(lambda ,params ,E ... ) true]
   [ _ false]
   ))

 
(define (lambda-and-wrap-expr? expr)
  (match
   expr
   [`(lambda ,params ,E ... ) true]
   [`(let ((,lname ,`(lambda ,params . ,E)))
       ,lname) 
    true
    ]
   [ _ false]
   ))

;; (lambda-and-wrap-expr? '(+ 1 2))
;; (lambda-and-wrap-expr? '(lambda (x) 1 2))
;; (lambda-and-wrap-expr? '(let ((name  (lambda (x) 1 2))) name ) )
;; (lambda-and-wrap-expr? '(let ((name  (lambda (x) 1 2))) name 3) )



(define (pre-alpha-expr-mod expr)
  (define lambda-names '())
  (define (rn expr)
    (match
     expr
     [`(lambda ,params ,E ... )
      (let ((lname (gensym 'lambda)))
	(set! lambda-names (cons lname lambda-names))
	`(let ((,lname ,`(lambda ,params . ,E)))
	   ,lname))]
     [`(if     ,E1 ,E2)	    `(when ,(rn E1) ,(rn E2))]
     ;[`(begin ,E ... )      

     [ (? pair?)
       (map rn expr)]
     [ _ expr]
     ))
  ;; (let ((r 
  (rn   (extract-main expr))
  ;))
  ;;   (values r lambda-names))
  )








     



;; (define (post-alpha-conv-mod  expr env freev)
;;   (define (ac ex)
;;     (match 
;;      ex
;;      [`(let ,(? symbol? V) ,bindings ,E ... )  ;;named let
;;       (cond 
;;        [(assoc V env) (set! env (alist-cons-update V V env))]
;;        [(assoc V freeb) (set! freev (alist-cons-update V V freev))])
;;       (map 
;;       (map ac E)
;;       ]
;;     ))

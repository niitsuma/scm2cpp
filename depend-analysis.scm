#lang racket

(provide 
 depend-analysis 
 ;top-level-functions-undef-types
 functions-undef-types-alist
 expr-type->global-vars
 )



;(require srfi/1)
(require (only-in srfi/1
		  lset-difference
		  lset=
		  lset-union
		  lset-adjoin
		  ;fold
		  lset-intersection
	 ))

;; This module imported cKanren without using any of it, which made the
;; whole translator need cKanren installed even on the Hindley-Milner
;; path, where no relational search runs at all.

(require "alist-util.scm")
(require "list-util.scm")

(require "alpha-conv.scm")
(require "type-symbols.scm")
(require "ck-util.scm")
(require "cl-util.scm")

(require "type-infer-util.scm")

;(require "schlep-name.scm")


(require racket/sequence)  



(define (depend-analysis 
	 expr
	 ;depends
	 ;mutables
	 ;refereds
	 ;undefvars
	 )
  (define nullset #())
  (define list->set list->vector)
  (define (enset e) (list->set (list e)))
  (define voidset (enset Void))


  ;(define aup alist-cons-update)
  ;(define (set+ l1 . ll) (apply lset-union (cons eq? (cons l1 ll))))
  ;(define (set+ l1 . ll) (apply vset-union (cons eq? (cons l1 ll))))
  (define (set+ l1 . ll) (apply vset-union (cons equal? (cons l1 ll))))
  (define (set-list-union ll) (apply vset-union (cons equal? ll)))

  ;(set+ '(1 2) '(4 1) '(3 9)) ;=> '(9 3 4 1 2)
  ;(set+ '(1 2) '(4 1) '()) ;=> '(9 3 4 1 2)

  ;(define (set-add l1 . vs) (apply vset-adjoin (cons eq? (cons l1 vs))))
  (define (set-add l1 . vs) (apply vset-adjoin (cons equal? (cons l1 vs))))
  ;(set-add #(1 2) 4 3 1)

  ;(define vars (map car ev))
  (define mutables #() )
  (define refereds #() )
  (define depends '() )
  (define funcalls '())
  (define lambdas '())
  (define local-lambdas '())
  (define function-scopes '())
  (define return-lambdas '())
  (define function-return-use '())
  (define function-return-not-use '())
  ;(define args null)




  ;(define relateds '())
  ;(define ref-lambdas '())
  ;(define (dups k vs) (set! depends (alist-lset-union-eq-update k vs depends)))
   ;(define (dups k vs) (set! depends (alist-vset-union-eq-update k vs depends)))
   (define (dups k vs) (set! depends (alist-vset-union-equal-update k vs depends)))
   (define (dup k v)
     ;(display (list k v (alist-vset-union-eq-update k (vector v) depends))) (newline)
     (set! depends 
          (alist-vset-union-equal-update k (vector v) depends)
          ))
  ;(dups 'x '(y z)) (dups 'a '(b c)) (dups 'a '(d e))  depends ;=> '((a e d b c) (x y z))

  (define (fups k vs) (set! funcalls (alist-vset-union-equal-update k vs funcalls)))
  (define (fup k v)   (set! funcalls (alist-vset-union-equal-update k (vector v) funcalls))
    (lup k)
    )


  ;(define (mups k)  (set! mutables (aup k true mutables)))
  (define (mup  v )  (set! mutables  (set-add mutables v)))
  (define (mups vs)  (set! mutables  (set+ mutables vs)))
  (define (rup  v)   (set! refereds  (set-add refereds v)))
  (define (rups vs)  (set! refereds  (set+ refereds vs)))
  ;refereds  ;(rups `(1 2)) 
  (define (drup k vs) (dups k vs) (rups vs))
  ;(define (drupn k vs) (drup k vs) nullset )

  (define (lup fname) (set! lambdas (lset-adjoin eq?  lambdas fname)))
  (define (sup fname) (set! function-scopes (lset-adjoin eq? function-scopes fname)))
  (define (sdown fname) (set! function-scopes (remq fname function-scopes)))
  ;; (define function-scopes  '(a b c))
  ;; (sdown 'a)
  ;; (remq 'a '(a b c) )

  
  (define (lsup fname) (lup fname)(sup fname))



  (define (add-function-return-use fname) (set! function-return-use (lset-adjoin eq? function-return-use fname)))
  (define (add-local-lambdas fname) (set! local-lambdas (lset-adjoin eq? local-lambdas fname)))


  
  (define (single-lambda-dep args ret) (vector `(lambda ,args ,ret) ))
  
  (define undefvars '())
  (define (new-undefvar)
    (let ([new-var (gensym 'UndefVar)])
      (set! undefvars (append `(,new-var) undefvars)) new-var))

  (define (lambda-arg-match fname params-set)
    ;(print)(newline)
    (set+
     (for/vector 
      ([i (list-vset->vset-list params-set)])
      (lambda-arg-match-single fname i))
     ))

  (define (lambda-arg-match-single fname params)
    (let([f-deps-cons (assoc fname depends) ] [lam-ret nullset] )
     (if (if (pair? f-deps-cons)
       (sequence-fold
	(lambda (tf sexp)
	  ;(print (list tf sexp))
	  (if (not tf)
	    (match sexp
	     [`(lambda ,args ,ret)
	      ;(print (list args params))(newline)
	      (let ([pat (list->correspond-ck args params)])
		;(print pat)(newline)
		(if (null? pat) #f
		 (begin 
		  (for-each
		   (lambda (x)
                     ;(display x)(newline)
		    (dup (car x) (cdr x))
		    (rup (cdr x)))
		  (car pat)) (set! lam-ret (set+ ret lam-ret)) #t))) ]
	     [ _  #f]  ) #f )  )  #f (cdr f-deps-cons))  #f)
	 lam-ret
	 (begin 
	   ;(dup fname `(lambda ,(new-undefvar)  ,(vector (new-undefvar)) ))
	   ;(set! lam-ret (lambda-arg-match fname params)) 
	   `(,Funcall ,fname,@params)
	   ;lam-ret
	 )
      )))

  
  (define (not-else? expr)
    (not (eq? expr 'else)))

  (define (da expr)
    ;(print `(da ,expr))
    (match 
     expr



     [(? boolean?) (enset Bool)]
     [(? exact-integer?) (enset Int)]
     [(? double?) (enset Double) ]
     [(? pure-complex?) (enset Complex)]
     [(? pure-rational?) (enset Rational) ]
     [(? string?) (enset String)]
     [(? char? e) (enset Char) ]
     [(quote (? symbol? )) (enset Symbol)]
     ;[(? number?) '()]
     ;[(? string?) '()]
     ;[(? char?) '()]
     ;[(? constant? c) '()]
     [(? constant? c) #()]
 
     [(? symbol?) (enset expr)]
     ;[(? symbol?) (vector expr)]

     [`(begin ,E0 (when ,E1 ,E2)) (set+ (da E0) (da  `(when ,E1 ,E2)))]
     [`(begin ,E0 (unless ,E1 ,E2)) (set+ (da E0) (da  `(unless ,E1 ,E2)))]
     [`(begin ,E0 (cond (,(? not-else? P)  ,E ...) ... ))
      ;(display `(cond . ,(map cons P E))) (newline) #()
      (set+ (da E0)  (da `(cond . ,(map cons P E))))]
     [`(begin ,E0 (case ,E1 (,(? not-else? P) ,E ...  )  ...))
      ;(display `(case ,E1 . ,(map cons P E))) (newline) #()
      (set+ (da E0)  (da `(case ,E1 . ,(map cons P E))) ) ]

     [`(begin (when ,E1 ,E2))  (set+ voidset (da `(when ,E1 ,E2)))]
     [`(begin (unless ,E1 ,E2))  (set+ voidset  (da `(unless ,E1 ,E2)))]
     [`(begin (cond (,(? not-else? P)  ,E ...) ... ))
      (set+ voidset (da `(cond . ,(map cons P E))))]
     [`(begin (case ,E1 (,(? not-else? P) ,E ...  )  ...))
      (set+ voidset (da `(case ,E1 . ,(map cons P E))) ) ]

     [`(begin ,E) (da E)]
     [`(begin ,E0 ,E ...)
      ;(display `(begin . ,E)) (newline) #()
      (da E0)
      (da `(begin . ,E))
      ;; (let ([daE (map da E)])
      ;; 	;(rups (apply set+ daE)) 
      ;; 	(last daE))  
      ]



     ;[ (list (? op-float->float? ) X) (da X) ]
     ;[ (list (? op-float->float? ) E ...) (set+ (map da E ))]
     ;[`( ,(? op-num-num->bool? o ) ,E ...) (set+ (map da E ))]
     ;[`(not ,X) (da X) ]
     [`(values ,E ...) `(values . ,(map da E))]
     
     [`(define ,(? symbol? v) ,E1) (drup v (da E1)) voidset]
     [`(set! ,v ,E1)       (mup v) (drup v (da E1)) voidset]
     [`(let ((,lambdaname  (lambda ,params ,E ... ))) ,lambdaname)
      (lsup lambdaname)
      (add-local-lambdas lambdaname)
      (let ([ret 
	     ;(single-lambda-dep params 
	     (da `(begin . ,E))
	     ;)
	    ])
	;(sdown lambdaname)
	;(print 
	(dup lambdaname `(lambda ,params ,ret))	
	;(dup lambdaname ret)	
	;ret
	(enset lambdaname)
	)]
     [`(lambda ,params ,E ... )
      (single-lambda-dep params (da `(begin . ,E)))
      ;`( (lambda ,params ,(da `(begin . ,E))))
      ]
     [`(define ,params ,E ... )
      (let* ([f (car params)] [xs (cdr params)]
	    [ret (begin (lsup f) (da `(begin . ,E))) ])
	;(sdown f)
	(dup f `(lambda ,xs ,ret)) #() )]
     [`(let ,(? symbol? v) ,bindings ,E ... )  ;;named let
      (lsup v)
      (add-local-lambdas v)
      (let ([vs (map da (map cadr bindings))]
	    [ret (da `(begin . ,E))]
	    [vars (map car bindings)] )
	;(display `( (lambda ,vars ,ret)) )(newline)
	;(display ret)(newline)
	(for-each drup vars vs)
	(dup v
	      ;(single-lambda-dep vars ret)
	      `( (lambda ,vars ,ret))
	      )
	;(sdown v)
	ret)]
     [`(let ((,X ,V) ... ) ,E ... )
      (for-each drup X (map da V))
      ;(for-each da V)
      (da `(begin . ,E))]
     [`(let* ,E ... ) (da `(let . ,E)) ]
     [`(letrec ,E ... ) (da `(let . ,E)) ]
     [`(letrec* ,E ... ) (da `(letrec . ,E))] 
     
     [`(do  ((,X ,V ,N) ...) 
	   (,LR ... ) 
	 ,E ... )
      ;(display LR)(newline)
      (for-each da X)
      (for-each mup X)
      (for-each drup X (map da V))
      (for-each drup X (map da N))
      ;(for-each da N)    
      (da `(begin . ,E))
      ;(da L) ;(da R)
      (let ([L (car LR)][R (cdr LR)])
	(da L)
	(if (null? R)
	    voidset      
	    (da (car R))))
      ]
     [`(when ,E1 ,E2) (rups (da E1))(da E2)]
     [`(unless ,E1 ,E2) (rups (da E1)) (da E2)]
     [`(if ,E1 ,E2) (rups (da E1))(da E2)]
     [`(if ,E1 ,E2 ,E3) (rups (da E1)) (set+ (da E2) (da E3))]
     [`(cond ,E ...)
      ;(let ((clauses (drop-right E 1))(last-clause (last E)))	
      ;(set+
      (set-list-union
       (map
	(lambda (clause)
	  (let ([r (da (car clause))] [nc (length clause) ]  )
	    (cond 
	     [(= nc 1) r]
	     [(and (= nc 3) (eq? (cadr clause) '=>)) (da `(,(caddr clause) ,(car clause)))]
	     [(eq? 'else (car clause)) (da `(begin . ,(cdr clause)))] 
	     [else (da `(begin . ,clause))]
	    )))
	E))]
     [`(case ,E1 (,P
		  ;(,V ... ) 
		  ,E ...  )  ...) 
      ;(display (list E1 V E))(newline)
      (rups (da E1))
      (for-each 
       (lambda (x)
	 (when (not-else? x)
	       (for-each da x)))
       P
       )
               ;(map (lambda (x) (display `(begin . ,x))) E)  
      ;(display (map (lambda (x) (da      `(begin . ,x))) E))
      (set-list-union (map (lambda (x) (da      `(begin . ,x))) E))
	    ;#()
      ]

	              
     [`(,(? scheme-primitive? o) ,E ...)
      (let ([vs (map da E )])
	(for-each rups vs)
      ;(display E)
      ;(display (map da E ))
	(set-list-union vs))]


     [`( ,(? symbol? fname)  . ,Es)
      (let ([vs (map da Es)])
	;(lambda-arg-match fname vs)
	(fup fname vs)
	(for-each rups vs)
	(list-vset->vset-list (cons Funcall (cons fname vs)))
	;#()
	)
      ]

     [`((,rator . ,rand1) . ,rand2)
      (let ([vs (map da rand2)]
	    [fname (da `(,rator . ,rand1))])
	;(fup fname vs)
	(vector-map
	 (lambda (f)(fup f vs)) 
	 fname)
	   ;(list-vset->vset-list `(,fname . ,vs))
	(for-each rups vs)
	(list-vset->vset-list 
	 (cons 
	  Funcall 
	  (cons 
	   fname 
	   vs))))
      ]
     ;[ _      
       
     ;;  (error "unknown-expression in aplha" expr)
     ;;  (list 'unknown_expression expr)
     ; ]
      )
     )

  (define (funcalls-analysis)
    (for-each
     (lambda (kv)
       (let ([fname (car kv)]
	     [vs (cdr kv)]
	     ;[params-set (list-vset->vset-list (cdr kv))]
	     )
	 ;(display params-set)(newline)
       (vector-map (lambda (v) (lambda-arg-match fname v) ) vs))) funcalls)
    (set! return-lambdas           
     (set-list-union
     (map
      (lambda (kv)
       (let ([fname (car kv)]
	     [vs (cdr kv)])
	 ;(display params-set)(newline)
       ;(apply set+ 
       (set-list-union
	(vector->list 
        (vector-map 
	(lambda (v) 
	  (match v
	   [`(lambda ,params ,ret) 
	    ;(vector-memq ret
		
	    (vector-filter
	     (lambda (r)(memq r lambdas))
	     ret)
	    ;(memq 'a '(k b c))
 	    ] 
	   [ _ #()]))
	vs)))
	))
	    depends)
     )
     )
     ;(display return-lambdas )(newline)

    (vector-map 
     (lambda (r)
       (match
	r
	[`(,Funcall ,fname ,args ... )
	 (add-function-return-use fname)]	
	[ _ '()]))       
       refereds)
    (set! function-return-not-use
	  (lset-intersection eq?
	   (lset-difference eq?  lambdas function-return-use)
	   local-lambdas)
	  )
     )
 ;;   (match 
  ;;    expr
  ;;    [`(,Funcall ,fname ,params ... )      
  ;;     ]
  ;;    [ (? pair?)
  ;;      (map funcall-analysis expr)]
  ;;    [ _ expr]
  ;;    ))
      
  ;(dup 'y 's)(dup 'x 'v)(dup 'y 't)(dup 'x 'u)
  (let (
        [r (da expr)]
        ;[r 1]
	)
    (funcalls-analysis)    
    (values r depends mutables refereds 
	    funcalls lambdas 
	    function-return-not-use
	    return-lambdas
	    local-lambdas
	    ;undefvars
	    )
    ))


(define (depend-analysis-test expr)
  (let-values (	[(ex ev fv) (alpha-conv expr) ])
  (depend-analysis 
   (pre-alpha-expr-mod ex)   )))


;; Funcall

;; (let ([expr
;;        ;(list 'Funcall136 1)  
;;        (list Funcall 1)
;;        ])
;;   (display expr)(newline)
;;   (match 
;;    expr
;;    [`(Funcall136 ,x) 0 ]
;;    [`(,Funcall ,x) (list 1 Funcall) ]
;;    [(list Funcall x) (list 2 Funcall)  ]
;; ))

(define (expr->global-vars expr)  
  (define (defv e)
    (match
     e
     [`(define (,fname ,args ...) ,E ... ) null]	
     [`(define ,name (lambda ,args ...) ,E ... ) null]
     [`(define ,name ,E ... ) name]
     [`(define-values (,id ...) ,B) id]
     [ _ null ]
     )

    )
  (flatten (filter (compose not null?) (map defv expr) ))
)


(define (expr-type->global-vars expr env-type)
  (filter
   (lambda (v)  
     (match
      (var-env->direct-type v env-type)
      [`(lambda ,E ...) false] 
      [_ true ]))    
   (expr->global-vars expr)
))
  



(define (vars-typeenv-unknown->unknown-types-except-lambda vars env-type unknown-typed-list)
  (remove-duplicates
   (lset-intersection
    eq? 
    (flatten (map 
	      (lambda (v)		
		(let ([t (var-env->direct-type v env-type)])
		  (if (member 'lambda (flatten t)) '()
		      t))) 
	      vars))
    unknown-typed-list)
   ))



(define (functions-undef-types-alist expr-top env-type unknown-typed-list [global-vars '()])  
  (define (deft expr)
    (match
     expr
     [`(define (,fname ,args ...) ,E ... )	
	(let-values ([(expr1 alpha1 free1)  (alpha-conv expr)])
	  (let ([undef-types
		 (vars-typeenv-unknown->unknown-types 		  
		  (map cdr alpha1) 
		  env-type unknown-typed-list)]
		[free-var-types
		 (vars-typeenv-unknown->unknown-types-except-lambda 
		  (lset-difference equal?
		   (map cdr free1) global-vars)
		  env-type unknown-typed-list)]
		)
	    ;(display (list alpha1 free1))(newline)
	    (list fname undef-types free-var-types)
	    ))]	  
     [ _ null ]
     )

    )
  (filter (compose not null?) (map deft expr-top) )
)


;; (functions-undef-types-alist
;;  '(begin 
;;     (define a 12)
;;     (define (f x y ) (g (+ x y a b)))
;;     (define (g u ) (f u) u )
;;     )    
;;  '(( x . x) (f . (lambda (x y) x)) (g . (lambda (u) u)))
;;  '(x y u b f g)
;;  '(b)
;; )    
;; ;=> '((f (y x) ()) (g (u) ()))


;; (functions-undef-types-alist
;;  '(begin 
;;     (define a 12)
;;     (define (f x y ) a b (+ x y) )
;;     (define (g u ) a b(f u) u )
;;     )    
;;  '(( x . x) (f . (lambda (x y) x)) (g . (lambda (u) u)) (b . b)  )
;;  '(x y u b f g)
;; )    
;; ;=> '((f (y x) (b)) (g (u) (b)))

;; (functions-undef-types-alist
;;  '(begin 
;;     (define a 12)
;;     (define (f x y ) (g (+ x y a b)))
;;     (define (g u ) (f u) u )
;;     )    
;;  '(( x . x) (f . (lambda (x y) x)) (g . (lambda (u) u)))
;;  '(x y u b f g)
;; )    
;; ;=> '((f (y x) (b)) (g (u) ()))



;; (define function-free-type-variable-bind-free-alist 
;;   (functions-undef-types-alist
;;  '(begin 
;;     (define a 12)
;;     (define (f x y ) (g (+ x y a b)))
;;     (define (g u ) (f u) u )
;;     )    
;;  '(( x . x) (f . (lambda (x y) x)) (g . (lambda (u) u)))
;;  '(x y u b f g)
;;  )
;; )    
;; function-free-type-variable-bind-free-alist 
;; (define free-type-variables (flatten (map (lambda (kv) (append (cadr kv) (caddr kv)))    function-free-type-variable-bind-free-alist)))
;; free-type-variables




;; (define (var-rename-env v env-alpha-list-total)
;;   (var-envs2gensym v env-alpha-list-total)
;; 	 var-envs2gensym
;; )




(define (top-level-functions-args expr)
  (define top-functions null)
  (define (tadd f)   (lstack-push! f top-functions))
  (define arg-vars null)
  (define (aadd f)   (lstack-push! f arg-vars))
  (define (aadds fs) (set! arg-vars (append fs arg-vars)))

  (define (def-fargs e)
    (match
     e
     [`(define ,params ,E ... )
      (let ([f (car params)] [xs (cdr params)])
	(tadd f)
	(aadds xs)	  
	)
      ]
     [ _  null]
     ))
  (for-each def-fargs expr)
  
  (values top-functions arg-vars)
)

  

  








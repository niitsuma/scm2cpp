;#lang racket

(module myutil racket

(provide 
 listo

 cadro caddro
 eq-caro
 memo
 reverseo

 lasto
 last-pairo

 <=in-order-list
 
 uniform-list-fn-o-n
 uniform-list-fn-o
 uniform-list-fno
 uniform-list-o-n
 uniform-list-o
 uniform-listo


 
 mapo
 for-eacho
 reduceo
 foldlo
 
 listo-ref
 listo-not-taged

 ;add-tailed-membero
 var-tailed-membero

 for-kanren
 for-conde-kanren

 reify-symbol?
 reify-symbol-n

 reify-lset-list-in-sexp


 list->correspond-rel
 list=>correspond-rel

 refine-rel-conditional-result

 ;type-env-match->type-env-rel-var

 scm?->rel
 debug-print-rel
 varo varnoto varo* varnoto*
 ==loose
 =<=force
 +==
 ;=/=regid
 ;==-instance



)

;; (require "mk.scm")
;; (require "ck.scm")
;; (require "miniKanren.scm")
;; (require "tree-unify.scm")
;; (require "matche.scm")
;; (require "neq.scm")
;; (require "tester.scm")

(require rkanren)

(require "alist-util.scm")
(require "cl-util.scm")
(require "list-util.scm")

; 3.5
(define (listo l)
  (conde
   ((nullo l) succeed)
   ((pairo l)
    (fresh (d)
	   (cdro l d)
	   (listo d)))))
 
; 3.54.1
(define (eq-caro l x) (caro l x))
;;(run* (q) (eq-caro '(1 2) q)) ;;=> '(1)



(define (cadro p b)
  (fresh (a c)
    (== `(,a ,b . ,c) p)))
;; (cadr '(1 2 3));=>2
;; (cadr '(1 2 ))
;; (run* (q) (cadro '(1 2) q)) ;;=> '(2)
;; (run* (q) (cadro '(1 2 3) q)) ;;=> '(2)


(define (caddro p c)
  (fresh (a b d)
    (== `(,a ,b ,c . ,d) p)))
;; (caddr '(1 2 3));=>3
;; (caddr '(1 2 3 4));=>3
;; (run* (q) (caddro '(1 2 3 4 5) q)) ;;=> '(3)
;; (run* (q) (caddro '(1 2 3) q)) ;;=> '(3)



(define (memo x l out)
  (conde
   ((nullo l) fail)
   ((eq-caro l x) (== l out))
   ((fresh (d)
     (cdro l d)
     (memo x d out)))))

(define (reverseo-rec l0 l1 y)
  (fresh (c d z)
   (conde 
    [(nullo l0) (== y l1)]     
    [(conso c d l0)
     (conso c l1 z)
     (reverseo-rec d z y)])))

;; (run* (q) (reverseo-rec '(1 2 3) '() q)) ;=> '((3 2 1))

(define (reverseo l x)  (reverseo-rec l '() x))

;;(run* (x)(reverseo x `(pasta e fagioli))) ;=> fail
;;(run* (x)(reverseo `(pasta e fagioli) x)) ;=> '((fagioli e pasta))


(define (lasto l x)
  (fresh (c d)
	 (conda
	  ;[(nullo l) (==  x l)]
	  [(conso c d l)
	   (conda
	    [(nullo d)(== x c )  ]
	    [(lasto d x)])]
	  [(== l x)])))
  
;; (run* (q) (lasto '(1 2 3) q)  ) => '(3)
;; (run* (q) (lasto '(1 2 3 . 4 ) q)  ) => '(4)



(define (last-pairo l x)
  (fresh (c d)
	 (conda
	  [(conso c d l)
	   (conda 
	    [(pairo d)
	     (last-pairo d x)]
	    [ (== x l)])]
	  [(== l x)])))

;;(run* (q) (last-pairo '(1 2 3) q)  )  ;=> '((3))
;; (run* (q) (last-pairo '(1 2 3 . 4 ) q)  ) ;=> '((3 . 4))
;;(run* (q) (last-pairo '( (1 . 2) ( 3 . 4 ) ) q)  ) ;=> '(((3 . 4)))
;;(run* (q) (last-pairo '( ( (1 . 2) ( 3 . 4 ) )) q)  )  ;=>  '((((1 . 2) (3 . 4))))


;; (define (last-pair-and-drop-reco l x y )
;;   (fresh (c d)
;; 	 (conda
;; 	  [(conso c d l)
;; 	   (conda 
;; 	    [(pairo d)
;; 	     (last-pair-and-dropod d x y)]
;; 	    [ (== x l) ])]
;; 	  [(== l x)])))



(define (<=in-order-list x y l)
  (fresh (xl)
    (memo x l xl) 
    (membero y xl)))

;(run* (q) (<=in-order-list 4 q '(1 2 3 4 5 6) )) ;;  '(4 5 6)
;(run* (q) (<=in-order-list 0 q '(1 2 3 4 5 6) ))
;(run* (q) (<=in-order-list 1 q '(1 2 3 4 5 6) ))


(define (uniform-list-fn-o-n l fno o n)
  (conde
   ((nullo l) (== n 0))
   ((fresh (c d m)
     (conso c d l)
     (fno c o)
     (uniform-list-fn-o-n d fno o m)
     (project (m) (== (add1 m) n)
)))))


(define (uniform-list-fn-o l fno o)
  (conde
   ((nullo l))
   ((fresh (c d)
     (conso c d l)
     (fno c o)
     (uniform-list-fn-o d fno o)))))

(define (uniform-list-fno l fno)
  (fresh (o)
    (uniform-list-fn-o l fno o)))

(define (uniform-list-o-n l o n)
  (uniform-list-fn-o-n l == o n))
(define (uniform-list-o l o)
  (uniform-list-fn-o l == o))
(define (uniform-listo l)
  (uniform-list-fno l == ))


;; (run* (q) (fresh (o n) (uniform-list-fn-o-n  '(a a a ) == o n)  (== q `(,o ,n)))) ;=> '((a 3))
;; (run* (q) (fresh (o n) (uniform-list-o-n  '(a a a ) o n)  (== q `(,o ,n)))) ;=> '((a 3))

;; (run* (q) (fresh (o n)
;;  (uniform-list-fn-o-n '() caro o n) (== q `(,o ,n)))) ;;ok
;; (run* (q) (fresh (o n )
;;  (uniform-list-fn-o-n '((1 . 2)  (1 . 3)) caro o n) (== q `(,o ,n)))) ;o=1
;; (run* (q) (fresh (o n)
;;  (uniform-list-fn-o-n '((1 . 2)  (2 . 3)) caro o n) (== q `(,o ,n)))) ;fail
;; (run* (q) (fresh (o)
;;  (uniform-list-fn-o '() caro o) (== q o) )) ;;ok
;; (run* (q) (fresh (o)
;;  (uniform-list-fn-o '((1 . 2)  (1 . 3)) caro o) (== q o))) ;o=1
;; (run* (q) (fresh (o)
;;  (uniform-list-fn-o '((1 . 2)  (2 . 3)) caro o) (== q o))) ;fail
;; (run* (q)(uniform-list-fno '((1 . 2)  (2 . 3)) caro));fail
;; (run* (q)(uniform-list-fno '((1 . 2)  (1 . 3)) caro));#s
 ;; (run* (q) (fresh (o)
 ;;  (uniform-list-fn-o 
 ;;   '((1 . 2)  (1 . 2)) 
 ;;   (lambda (x y) (== x y))
 ;; o) (== q o))) 

(define mapo
  (lambda (fo ls q)
    (conde
      [(nullo ls ) (== q '())]
      [(fresh (a d a^ d^)
          (conso a  d ls)
          (conso a^ d^ q)
          (fo a a^)
          (mapo fo d d^))])))

;; (run* (q) (mapo caro '((a . 2)  (b . 3)) q))
;; (run* (q) (mapo cdro '((a . 2)  (b . 3)) q))

;; (run* (q) 
;;       (mapo 
;;        (lambda (x y) (fresh (z) (caro x z) (conso z 9 y)))  
;;        '((a . 2)  (b . 3)) q)) ;=>'(((a . 9) (b . 9)))


(define (foldlo fo e0 ls q)
    (conde
      [(nullo ls ) (== q e0)]
      [(fresh (a d a^)
          (conso a  d ls)
          (fo a e0 a^)
          (foldlo fo a^ d q))]))

;; (run* (q)        (foldlo conso '() '(1 2 3) q))

(define (reduceo fo ls q)  
  (fresh (a d)
	 (conso a d ls)	 
          (foldlo fo a d q)))

;; (run* (q) (reduceo conso '( () 1 2 3) q))



(define for-eacho
  (lambda (fo ls)
    (conde
      [(nullo ls )]
      [(fresh (a d )
          (conso a  d ls)
          (fo a)
          (for-eacho fo d))])))

;(run* (q) (for-eacho (lambda (x) (scm?->rel number? x)) '(1 2 3)))
;(run* (q) (for-eacho (lambda (x) (scm?->rel number? x)) '(1 2 a)))




(define (listo-ref l n q)
  (if (= n 0)
      (caro l q)
      (fresh (c d)
	     (conso c d l)
	     (listo-ref d (sub1 n) q))))

;(run* (q) (listo-ref '(1 2 3 4) 3 q)) ;;=> '(4)



(define (listo-not-taged l tag)
  (fresh (x y)
	 (== l `(,x . ,y))
	 (=/= x tag)))



	 


(define (var-tailed-membero x l)
  (fresh (c d)
   (conso c d l)   
   (conda
    [(== x c)]
    [(=/= x c)(var-tailed-membero x d)])))

;; (run* (q)(var-tailed-membero 1 q ))
;; (run* (q)(fresh (x)(var-tailed-membero x q ))) ;=>'((_.0 . _.1))
;; (run* (q)(fresh (x y r)(var-tailed-membero x r ) (var-tailed-membero y r)(== q `(,x ,y ,r)  ))) ;=> '((_.0 _.0 (_.0 . _.1)))
;; (run* (q)(fresh (x y r)(var-tailed-membero `(1 . ,x) r ) (var-tailed-membero `(2 . ,y) r)(== q `(,x ,y ,r)  )))
;; ;=> '((_.0 _.1 ((1 . _.0) (2 . _.1) . _.2)))


;; (define (add-tailed-membero x l)
;;   (fresh (c d)
;;    (conso c d l)
;;    (conda
;;     [(== c x)]
;;     [
;;      ;(=/= c x)
;;      (conda
;;       [
;;        (varnoto d)
;;        (add-tailed-membero x d)
;;       ]
;;       [(varo d)
;;         (fresh (dc dd)
;;            (conso dc dd d)
;; 	   (== dc x))
;;        ]
;;       )      
;;       ]
;;     ;[(add-membero x d)]
;;    )))

;; (run* (q) 
;;    (fresh (x y)
;; 	  ;(== q `(, x . ,y ))	  
;; 	  ;(== q `(3 1 . ,y ))
;; 	  (add-taild-membero 1 q )
;; 	  (add-tailedmembero 2 q )
;; 	  ;(add-tailed-membero 2 q )
;; ))
;; ;=> '((1 2 . _.0))

;; (run* (q) 
;;    (fresh (x y)
;; 	  ;(== q `(, x . ,y ))
;; 	  (== q `(3 1 . ,y ))
;; 	  (add-tailed-membero 1 q )
;; 	  (add-tailed-membero 2 q )
;; 	  ;(add-membero 2 q )
;; ))
;; ;=> '((3 1 2 . _.0))



(define (for-kanren ps)
  (if 
   (null? ps)
   succeed
   (conde
    [(nullo ps)]
    [(car ps)
    ;(cadr ps)
    (for-kanren (cdr ps))
    ])
   ))

;; (define rel-ps (list (== 1 1) (== 2 2) ) )
;; (run* (q) (for-kanren  rel-ps))
;; (run* (q) (for-kanren  '()))
;; (let* (
;;        [n 0]
;;        [env `((x . ,(var 'x))  
;; 	      (y . ,(var 'y))   
;; 	      (z . ,(var 'z))  ) ]
;;        [ps (map (lambda(kv)
;; 		  (set! n (+ 1 n ))
;; 		  (== (cdr kv) n)) 
;; 		env  )   ]
;;        )
;;   (run* (q) (for-kanren ps) (== q env) )
;; )
;; ;;=>'(((x . 1) (y . 2) (z . 3)))

;; (let* (
;;        [n 0]
;;        [env `((x . ,(var 'x))  
;; 	      (y . ,(var 'y))   
;; 	      (z . ,(var 'z))  ) ]
;;        [ps (list
;; 	    (conde 
;; 	     [(== (cdr (assoc 'x env)) 
;; 		  (cdr (assoc 'y env))) ]
;; 	     [(== (cdr (assoc 'x env)) 
;; 		  (cdr (assoc 'z env))) ])	    
;; 	    (== (cdr (assoc 'x env))  1)
;; 	    )
;; 	]       
;;        )
;;   (run* (q) (for-kanren ps) (== q env) )
;; )
;; ;;=> '(((x . 1) (y . 1) (z . _.0)) ((x . 1) (y . _.0) (z . 1)))

(define (for-conde-kanren l)
  (if (null? l)
      ;succeed
      fail
      (conde 
       [(car l)]
       [ (for-conde-kanren (cdr l) )])
      ))

;; (let* (
;;        [ x (var 'x)]
;;        [ y (var 'y)]
;;        [ z (var 'z)]
;;        [rel-ps 
;; 	(list 
;; 	 (== z x)
;; 	 (== z 2)
;; 	 )]
;;        [p0
;; 	 (conde
;; 	  [(car rel-ps)]
;; 	  )
;; 	 ]
;;        )
;;   (run* (q) 
;; 	;p0
;; 	(for-conde-kanren rel-ps)
;; 	(== q (list x y z))
;; ))



(define (list->correspond-rel l1 l2)
  (let* ([env '()] 
	 [ll1 (map-tree
	       (lambda (x) 
		 (let ([v (var x)])
		   (set! env `( (,x . ,v)  . ,env ))
		   v)) l1 ) ])
    (run* (q) (== ll1 l2)(== q env))
   ))

;; (list->correspond-rel '(x (y z )) '(1 (a 3)))
;; ;;=> '(((z . 3) (y . a) (x . 1)))
;;(list->correspond-rel '(x . y) '(1 (a 3)))
;(list->correspond-rel '(x ) '(1 (a 3)))



(define (list<->correspond-rel->envs l1 l2)
  (let* ([env1 '()] [env2 '()]
	 [ll1 (map-tree
	       (lambda (x) 
		 (let ([v (var x)])
		   (set! env1 `( (,x . ,v)  . ,env1 ))
		   v)) l1 ) ]
	 [ll2 (map-tree
	       (lambda (x) 
		 (let ([v (var x)])
		   (set! env2 `( (,x . ,v)  . ,env2 ))
		   v)) l2 ) ]
	 )
    (run* (q) 
	  (== ll1 ll2)
	  ;(conda [(== ll1 l2)] [(== ll2 l1)])
	  (== q (list env1 env2)))
   ))

;; (list<->correspond-rel->envs '(x (y z )) '(1 (a 3)))
;; ;;=> '(((z . 3) (y . a) (x . 1)))
;; (list<->correspond-rel->envs '(x . y) '(1 (a 3)))
;; (list<->correspond-rel->envs '(x ) '(1 (a 3)))


(define (list=>correspond-rel l1 l2)
  (define (cons-reverse x) (cons (cdr x) (car x)))
  (let ([envss (list<->correspond-rel->envs l1 l2)])
    (if 
     (null? envss)
     envss
     (let* (
	    [envs (car envss)]
	    [reifies (reify-lset-list-in-sexp envs)]
	    [env1 (car envs)]
	    [env2 (cadr envs)]
	    [renv1 (map cons-reverse env1) ]
	    [renv2 (map cons-reverse env2) ]
	    [assings '()]
	    )
       ;(print envs)
       (for-each
	(lambda (r)
	  (let (
		[r1 (assoc r renv1)] 
		[r2 (assoc r renv2)]
		)
	    (when 
	     (and 
	      (pair? r2) (not (pair? (cdr r2)))
	      (pair? r1) (not (pair? (cdr r1)))
	      )
    	     (begin 
    	       (set! assings `( (,r . ,(cdr r2)) .  ,assings ))
    	       (set! renv2 (remove r2 renv2)))
					;(when (and (pair? r1) (not (pair? (cdr r1))))
					;   (set! assings `( (,r . ,(cdr r1)) .  ,assings ))
					;  )
    	     )))
	reifies)
       ;(print assings)
       (set! renv1 (cl:sublis assings renv1))
       ;(print renv1)
       (set! renv2 (cl:sublis assings renv2))
       ;(print renv2)
       (append (map cons-reverse renv1) 
	       (map cons-reverse renv2)
	       ;renv2
	       )
       ))))

;; (list=>correspond-rel '(x (y z )) '(1 (a 3)))
;; (list=>correspond-rel '(x (y z )) '(1 3)) ;;=>'((z . _.0) (y . _.1) (x . 1) (3 _.1 _.0))
;; (list->correspond-rel '(x (y z )) '(1 3)) ;;fail
;; ;;=> '(((z . 3) (y . a) (x . 1)))
;; (list->correspond-rel '(x . y) '(1 (a 3)))
;; (list->correspond-rel '(x ) '(1 (a 3))) ;;fail '()

	 
;(define (list-correspond-vset l1 l2)
  
	 

;; (list=>correspond-rel '(x (y z )) '(1 (a 3)))
    



(define (refine-rel-conditional-result l)
  (remove-duplicates
   (map 
    (lambda (x)
      (match 
       x
       [`(,Expr : ,Cond ) Expr]
       [_ x]))
       ;(if (member ': x) (remove*  (member ': x) x)x)
  ;(filter 
   ;(lambda (x) (not (member ': (flatten x))))   
	  (remove-duplicates l)
	  )))





(define (reify-symbol? x)
  (if (symbol? x)
      (regexp-match
       #rx"_.[0-9]+"
       (symbol->string x))
      false))

(define (reify-symbol-n x)
  (if (reify-symbol? x)
      (string->number (cadr (regexp-split #rx"_." (symbol->string x)))) 
      -1
      ;false
      ))

;(reify-symbol? '_.23)
;(reify-symbol-n '_.23)
;#rx"aa?" 
;(regexp #rx"_.[0-9]+"  "_.123")
;(regexp-split #rx"_.[0-9]+"  "_.123a") 
;(regexp-split #rx"_.[0-9]+"  ".123a") 
;(regexp-match #rx"_.[0-9]+"  "_.123") 
;(if false "a" "b")


(define (reify-lset-list-in-sexp expr)
  (remove-duplicates (filter reify-symbol? (flatten expr))))


(define (reify->var-sexp-env expr)
  (let* ([vs (reify-lset-list-in-sexp expr)]
	 [xvs (map (lambda (x) (cons x (var x))) vs)])
    (values (cl:sublis xvs expr) xvs)))

;(reify->var-sexp-env '(list x (list x y _.0 )))
;(reify-lset-list-in-sexp '(list x (list x y _.0 )))

    
    






(define (scm?->rel f? . xs)
  (goal-construct (scm?->rel-c f? xs)))

(define (scm?->rel-c f? xs)
    (lambdam@ 
     (a : s c )
     (let loop-xs ((x (car xs)) (xr (cdr xs)) (xo '() ))       
	   (let ((x (walk* x s)))
	     (cond
	      ;[(var? x) #f]
	      [(any/var? x) a]
	      ;[(pair? x)	      		 
	      ; (loop (car x)) (loop (cdr x))
	      ; ] 
	      [(null? xr)(if (apply f? (reverse (cons x xo))) a #f)]
	      (else
	       (loop-xs (car xr) (cdr xr) (cons x xo))))))))

	       	     
;; (run* (x) (== x 3)
;;       (scm?->rel number? x));=>(3)


;; (run* (q) 
;;       (fresh (x y)
;;       (== x 3)
;;       (== y 5)
;;       (scm?->rel <  x y)
;;       (conso x y q)
;;       )) ;=> '((3 . 5))


;; (run* (x) (== x 'a)
;;       (scm?->rel number? x));=>'()

;; (run* (x) (scm?->rel number? x) 
;;       (== x 3))  ;=>(3)
;; (run* (x) (scm?->rel number? x));=> '(_.0)

;; (run* (q)
;;       (fresh (x y)
;;       (== x  3)
;;       (== y  5)
;;       (scm?->rel < x y)
;;       (conso x y q)
;;       ))

;; (run* (q)
;;       (fresh (x y)
;;       (== x  3)
;;       (== y  5)
;;       (scm?->rel pair? q)
;;       (conso x y q)
;;       ))



;; (run* (q)
;;       (fresh (x y)
;;       (conso x y q)
;;       ))



(define (debug-print x) (display x)(newline) #t)
(define (debug-print-rel  x) (scm?->rel debug-print x)) 

(define (varo-c x)
 (lambdam@ (a : s c )
  (let ((x (walk x s)))
   (if (var? x) a #f))))
(define (varo*-c x)
 (lambdam@ (a : s c )
  (let ((x (walk* x s)))
   (if (any/var? x) a #f))))
(define (varnoto-c x)
 (lambdam@ (a : s c )
  (let ((x (walk x s)))
   (if (var? x) #f a))))    
(define (varnoto*-c x)
 (lambdam@ (a : s c )
  (let ((x (walk* x s)))
   (if (any/var? x) #f a))))
(define (varo x)
  (goal-construct (varo-c x)))
(define (varnoto x)
  (goal-construct (varnoto-c x)))
(define (varo* x)
  (goal-construct (varo*-c x)))
(define (varnoto* x)
  (goal-construct (varnoto*-c x)))



;; (run* (q)
;;     (== q 3)  
;;     (varo q))

;; (run* (q)
;;     (varo q)
;;     (== q 3)  
;; )


;; (run* (q)
;;       (conde
;;        ((== q 3))       
;;        ;((varnoto q))
;;        ((varo q))
;;        )
;;       ;)
;;       (conde
;;        ((== q 2))
;;        ((varnoto q))
;;       )
;;       )




(define ==loose (lambda (u v) (goal-construct (==loose-c u v))))

(define ==loose-c
  (lambda (u v)
    (lambdam@ (a : s c)
      (cond
        ((unify `((,u . ,v)) s)
         => (lambda (s^)
              ((update-prefix s s^) a)))
        (else 
	 a ;;; always succeed
	 )))))

;; ;;; same without  goal-construct 
;; (define (==loose u v) 
;;   (lambdag@ (a)	   
;;    (cond
;;     ((
;;       (lambdam@ (a : s c)
;; 	(cond
;;         ((unify `((,u . ,v)) s)
;;          => (lambda (s^)
;;               ((update-prefix s s^) a)))
;;          (else a )))
;; 	 a
;; 	 )
;; 	 => unitg)
;;         (else (mzerog)))))

;; (run* (q)       (==loose q 3)       (==loose q 5) ) ;=> 3
;; (run* (q)       (== q 3)        (==loose q 5) ) ;=> 3
;; (run* (q)       (==loose q 3)        (== q 5) ) ;=> '()


;(update-s `( ( ( ,(var 'x) . 1 )  ( ,(var 'y) . 2 ) ) . c))






(define unify<force
  (lambda (e s)
    (cond
      ((null? e) s)
      (else
       (let loop ((u0 (caar e)) (v0 (cdar e)) (e (cdr e)))
         (let ((u (walk u0 s)) (v (walk v0 s)))
           (cond
             ((eq? u v) (unify<force e s))
             ((var? u)
              (and (not (occurs-check u v s))
                   (unify<force e (ext-s u v s))))
             ((var? v)
              (and (not (occurs-check v u s))
                   (unify<force e (ext-s v u s))))
	     
             ((and (pair? u) (pair? v))
              (loop (car u) (car v)
                `((,(cdr u) . ,(cdr v)) . ,e)))

             ((equal? u v) (unify<force e s))
	     
	     ((var? u0)
	      (and (not (occurs-check u0 v0 s))
		   (unify<force e (alist-cons-update u0 v0 s))))
	     ((var? v0)
	      (and (not (occurs-check v0 u0 s))
		   (unify<force e (alist-cons-update v0 u0 s))))	     

             (else #f)
	     
	     )))))))




(define (=<=force u v) 
  (lambdag@ (a)
    (lambdaf@ ()   
     ( (lambdam@ (a : s c)
	(let ([ss (unify `((,u . ,v)) s)])
	  (cond
           (ss  => (lambda (s^)
		     (unitg
		      ((update-prefix s s^) a))))
	   (else
	    (let ([sss (unify<force `((,u . ,v)) s)]) 
	     (cond
	      (sss
	       (mplusg* 
	        (unitg
		 ;((update-prefix s sss) a)
		 (make-a sss c)
		 )
	        (unitg a)))
	      (else (mzerog a))))
	    )
	   ))) a)
)))

(define  +== =<=force)





;; (run* (q)
;;        (=<=force q 3)
;;        (=<=force q 5)
;; ) ;;=> (5 3)

 
;; (run* (q)
;;   (fresh (r s) 
;;        (=<=force r 3)
;;        (=<=force r 5)
;;        (=<=force s r)
;;        (=<=force s 7)
;;        (== q `(,r ,s ))
;;        )
;; ) ;=> '((5 7) (3 7) (5 5) (3 3))


;; (define-syntax atleast
;;   (syntax-rules ()
;;     ((_ g0 g ... )
;;      (lambdag@ (a) 
;;        (lambdaf@ ()
;; 	 (let ((a1 a)  (gg (bindg* (g0 a) g ...)))
;;          (mplusg* 
;; 	  a1
;;           gg )))))))


;; (run* (q)
;;   (atleast (== q 3))
;;   (atleast (== q 4))
;; )








;; (define =/=regid-neq-c
;;   (lambda (p)
;;     (lambdam@ (a : s c)
;;       (cond
;;         ((unify p s)
;;          =>
;;          (lambda (s^)
;;            (let ((p (prefix-s s s^)))
;;              (cond
;;                ((null? p) #f) ;double unify no reduce logical var = no var before  =/= affected
;;                (else 
;; 		;((normalize-store p) a)
;; 		a
;; 		;#f
;; 		)))))
;;         (else a)))))


;; (define =/=regid
;;   (lambda (u v)
;;     (goal-construct (=/=regid-c u v))))

;; (define =/=regid-c
;;   (lambda (u v)
;;     (lambdam@ (a : s c);;s= car a  c=cdr a
;;       (cond
;;         ((unify `((,u . ,v)) s) 
;;          => (lambda (s^)
;; 	      ;; (let (
;; 	      ;; 	    (u (walk* u s^))  (v (walk* v s^))
;; 	      ;; 	    ;(u (walk* u s))  (v (walk* v s))
;; 	      ;; 	    (s-del (prefix-s s s^))
;; 	      ;; 	    )
;; 	      ;; 	(cond
;; 	      ;; 	 ;[(or (any/var? u)  (any/var? v) ) #f ]
;; 	      ;; 	 [else #f]))))
;; 	      ((=/=regid-neq-c (prefix-s s s^)) a)))
;;         (else a)))))


;; (run* (q)
;;       (conde
;;        ((== q 3))
;;        ((=/=regid q 3))
;;        ;((=/= q 3))
;;        )
;;       ;)
;;       (conde
;;        ((== q 2))
;;        ((=/=regid q 2))
;;        ;((=/= q 2))
;;       )
;;       )



;; ;; (run* (q)
;; ;;       (== q 3)
;; ;;       (debug-print-rel  q)
;; ;; );;=> 3 newline '()


;; ;; ;(define ==-instance (lambda (u v) (goal-construct (==-instance-c u v))))

;; ;; (define ==-instance 
;; ;;   (lambda (u v) 
;; ;;     (lambdag@ 
;; ;;      (a) 
;; ;;      (inc 
;; ;;       (mplusg* 
;; ;;        (bindg* (g0 a) g ...)
;; ;;        (bindg* (g1 a) g^ ...) ...)))))

;; ;; (goal-construct (==-instance-c u v))))

;; ;; (define ==-instance-c
;; ;;   (lambda (u v)
;; ;;     (lambdam@ (a : s c)
;; ;;       (cond
;; ;;         ((unify `((,u . ,v)) s)
;; ;;          => (lambda (s^)
;; ;;               ((update-prefix s s^) a)))

;; ;; 	[(and (not (var? u)) (not (var? v))) s]

;; ;;         (else #f)))))






)

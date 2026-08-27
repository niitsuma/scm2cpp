#lang racket/base
;#lang racket


(require (prefix-in schemeunit: rackunit))
(require (prefix-in schemeunit: rackunit/text-ui))

(require cKanren)

;; (require (only-in 
;; 	  "mk.scm"
;;                     var var?
;; 		    conda conde 
;; 		    == 
;; 		    =/= 
;; 		    fail
;; 		    ;never-pairo
;; 		    ;pairo
;; 		    run*
;; 		    fresh
;; 		    ;membero
;; 		    numbero		    
;; 		    occurs-check
;; 		    reify-s
;; 		    walk*
;; 		    ))



;; (run* (q)  (== q 3))


;; (run* (q)
;;       (fresh (x y)
;; 	     (== x y))
;;  )


;(require rackunit/text-ui)


;; (require rackunit
;;          "file.scm")



;; (check-equal? (my-+ 1 1) 2 "Simple addition")
;; (check-equal? (my-* 1 2) 2 "Simple multiplication")


;; ;; (test-begin
;; ;;  (let ((lst (list 2 4 6 9)))
;; ;;    (check = (length lst) 4)
;; ;;    (for-each
;; ;;     (lambda (elt)
;; ;;       (check-pred even? elt))
;; ;;     lst)))


;; (test-case
;;  "List has length 4 and all elements even"
;;  (let ((lst (list 2 4 6 9)))
;;    (check = (length lst) 4)
;;    (for-each
;;     (lambda (elt)
;;       (check-pred even? elt))
;;     lst)))

(require racket/include)
(include "../common-test.scm")

(define base-tests
  (schemeunit:test-suite
       "Base Tests for mk.scm"

       (schemeunit:check-equal? 
	(run* (q) (== q 3))  
	'(3)  
	"Simple == ")
   
	(let* ([x (var 'x)]
	       [y (var 'y)]
	       [z (var 'z)]
	       [s `( (,z . ,5) (,x . ,y)  (,y . ,z) )]
	       )
	  (schemeunit:check-equal?
	   (walk x s)
	   5 
	   "simple walk ")
       	  )

	(let* ([x (var 'x)]
	       [y (var 'y)]
	       [z (var 'z)]
	       [s `( (,z . ,5) (,x . ,y)  (,y . ,z) )]
	       )
	  (schemeunit:check-equal?
	   (walk x s)
	   5 
	   "simple walk inside let")
	  )
	
	(schemeunit:check-equal?
	 (run* (q)	       
	       (== q '(1 )))
	 '((1))
	 )
	   


     (schemeunit:check-equal?      
	 (run* (q)	       
	       (== q 1)
	       (== q 2)
	       )
	 '()
	 )

     


))










 (define mk-neq-tests
   (schemeunit:test-suite
       "neq Tests for mk.scm"
       
   (schemeunit:check-equal?
	(run* (q)
	      (=/= q 1)
	      (== q 1)
	      )
	'()
	"(=/= fail) "
	)


    (schemeunit:check-equal?
	(run* (q)
	      (=/= q 1) )
	'(( _.0 : ( =/= ( (_.0 . 1) ) ) ))
	"(=/= q 1) "
	)
))








      



 





	;; (run* (q) (== q 2) (never-pairo q))
	;; (run* (q) (never-pairo q))
	;; (run* (q) (numbero q))
	;; (run* (q) (numbero q) (never-pairo q) )



	;; (let* ([x (var 'x)]
	;;        [y (var 'y)]
	;;        [z (var 'z)]
	;;        [s `( (,z . ,x) (,x . ,y)  (,y . ,z) )]
	;;        [r (walk x s) ]
	;;        )
	;;   ;(schemeunit:check-eq?
	;;   r
	;;   (eq? r y)
	;;    ;z 
	;;    ;"cyclic walk inside let")
	;;   )


(schemeunit:run-tests base-tests)

(schemeunit:run-tests mk-neq-tests)



;; (define (my-mat expr)
;;   (matche 
;;    expr
;;    [(,x ,y)
;;     (fresh (z)
;; 	   (conso z x y))
;;     ]
;;    ))

;; (run* (q) (my-mat q))

;; (run* 
;;  (q)     
;;  (matche 
;;   '(1 2 3)
;;   [(,x . ,r) (== q 1)]
;;   [(,x . ( ,y . ,r))  (== q 2)]
;; ));;(1 2)

;; (run* 
;;  (q)     
;;  (matche 
;;   ;'(1 2)
;;   ;'(1 2 3)
;;   '(1)
;;   [(,x) (== q 1)]
;;   [(,x . ,r)  (== q 2)]
;; ))

;; (define (matchetest x q)
;;   ;(debug-print-ck x)
;;   (matche 
;;    x
;;    [(aa . ,r)
;;     ;(debug-print-ck r)
;;     (matchetest r q) 
;;     ;(== q r)
;;     ]
;;    [(bb)(== q 2)
;;     ;(debug-print-ck x)
;;     ]

;;    [(cc . ,r)
;;     (matchetest `(aa . ,r) q) 
;;     (matchetest '(bb) q) 
;;     ;(debug-print-ck x)
;;     ]

;;    ))

;; (run*  (q) (matchetest '(aa bb) q) )
;; (run*  (q) (matchetest '(cc bb) q) )

;; ;; (define (matchetest2 x q)
;; ;;   (matche 
;; ;;    x
;; ;;    [(begin . ,E)
;; ;;     (map 
;; ;;      (lambda (x) (lambda ()(caro x q)))
;; ;;      E)
;; ;;     ]))

;; ;; (run*  (q) (matchetest2 
;; ;; 	    '((1 . 2) (1 . 3)) q))



;; (run* 
;;  (q)     
;;  (matche 
;;   '(1 2)
;;   ;'(1 2 3)
;;   ;'(1)
;;   [(,x . ,r)
;;    (conda 
;;     ((nullo r) (== q 1))
;;      ((== q 2)))]
;; ))




;; (run* 
;;  (q)     
;;  (matche 
;;   '(1 2 3)
;;   ;'(1 2)
;;   [(,x . ,r) 
;;    (matche
;;     r
;;     [(,x1 . ,r1 ) (== q 1)]
;;     [(,x1 )       (== q 2)])
;;    ]
;;   [(,x . ( ,y . ,r))  (== q 3)]
;; ))

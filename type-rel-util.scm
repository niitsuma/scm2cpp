#lang racket

(provide 
 number-typeo
 type-list-+==->condition-list
)


(require "type-symbols.scm")
(require "rel-util.scm")


(require rkanren)
;; (require (only-in rkanren
;;                     var var?
;; 		    conda conde 
;; 		    == 
;; 		    =/= 
;; 		    ;fail
;; 		    never-pairo
;; 		    pairo
;; 		    run*
;; 		    membero
;; 		    ))



(define (number-typeo expr)
  ;; A body that lists goals returns only the last one; the disequalities
  ;; before it were built and discarded.  fresh with no variables conjoins
  ;; them, which is what was meant.
  (fresh ()
   (never-pairo expr) 
   (=/= expr Optional)
   (=/= expr Bool)
   (=/= expr Char)
   (=/= expr String)
   (=/= expr Symbol))
  ;; (conde
  ;;  [(pairo expr)  
  ;;   (listo-not-taged expr 'list) 
  ;;   (listo-not-taged expr 'make-list) 
  ;;   (listo-not-taged expr 'vector) 
  ;;   (listo-not-taged expr 'make-vector) ]
  ;;  [(never-pairo expr) 
  ;;   (=/= expr Optional)]
  ;;  )
  )


;(define (not-list-typeo l)
;  (listo-

;(define (not-list-typeo l)
;  (listo-



(define (type-list-+==->condition-list l1 l2)
  (map
   (lambda (x y)
     ;(+== x y) 
     (conda
      [(varo x)
       (conde
	;[succeed]
	[(== x y )])]
      [(== x y) ]
      [succeed]
      )
     )
   l1 l2))


;; (run* (q)
;;       (conde
;; 	[succeed]
;;        [(== q 1)]
;;        [(== q 2)]))
       



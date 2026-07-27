#lang racket

(provide
 cons-reverse

 for-each-tree
 ;identity 
 r-cons 
 r-append
 copy-tree
 reverse-tree
 map-tree
 flatten-tree
 length-tree
 filter-tree
 find-if-tree
 ;print
 loop
 while
 find-if
 append-atom
 memoize 

 s-read

 list->stack
 stack-push!
 stack-pop!
 stack-top 
 stack-ref
 stack-set!
 stack-set-apply! 
 stack-map! 

 lstack-push!
 lstack-pop!

 list-correspond

 list-vset->vset-list
 vector-add

 call-with-values-ref
 call-with-values-ref0
 call-with-values-ref-arg
 call-with-values-ref0-arg

)

(require mzlib/defmacro)

(define (cons-reverse kv)  (cons (cdr kv) (car kv)))
;; (cons-reverse '(1 2 3)) ;=> ((2 3) . 1)



;; from http://www.geocities.co.jp/SiliconValley-PaloAlto/7043/
(define (for-each-tree f g n tree)
  (cond ((null? tree) n)
        ((not (pair? tree)) (f tree))
        (else
         (g (for-each-tree f g n (car tree))
            (for-each-tree f g n (cdr tree))))))
(define (identity obj)  obj)
(define (r-cons x y)  (append y (list x)))
(define (r-append x y)  (append y x))
(define-syntax block
  (syntax-rules ()
    ((block tag body1 body2 ...)
     (call-with-current-continuation
      (lambda (tag)
        body1 body2 ...)))))
(define (copy-tree tree)  (for-each-tree identity cons '() tree))
(define (reverse-tree tree)  (for-each-tree identity r-cons '() tree))
(define (map-tree f tree)  (for-each-tree f cons '() tree))
(define (flatten-tree tree)  (for-each-tree list append '() tree))
;; (define (sum-tree tree)  (for-each-tree + + 0 tree))
;; (define (mul-tree tree)  (for-each-tree * * 1 tree))
(define (length-tree tree)  (for-each-tree (lambda (x) 1) + 0 tree))
(define (filter-tree f tree)  (for-each-tree (lambda (x) (if (f x) (list x) '())) append '() tree))
(define (find-if-tree f tree)
  (block return
    (for-each-tree (lambda (x) (if (f x) (return x) #f))
                   (lambda (x y) #f)
                   #f
                   tree)))

;; (define (max-tree tree)
;;   (for-each-tree identity
;;                  (lambda (x y) (if (and x y) (max x y) (or x y)))
;;                  #f
;;                  tree))

;; ;; usage
;; > (copy-tree tree)
;; (1 (2 3) (4 (5 6) 7 ((8)) 9 10))

;; > (reverse-tree tree)
;; ((10 9 ((8)) 7 (6 5) 4) (3 2) 1)

;; > (map-tree - tree)
;; (-1 (-2 -3) (-4 (-5 -6) -7 ((-8)) -9 -10))

;; > (flatten-tree tree)
;; (1 2 3 4 5 6 7 8 9 10)

;; > (sum-tree tree)
;; 55

;; > (mul-tree tree)
;; 3628800

;; > (length-tree tree)
;; 10

;; > (filter-tree odd? tree)
;; (1 3 5 7 9)

;; > (find-if-tree (lambda (x) (= x 5)) tree)
;; 5

;; > (max-tree tree)
;; 10


(define (print . objs)
    (for-each (lambda (o) (display o)) objs)
    (newline))
(define-syntax loop
  (syntax-rules ()
    ((loop tag body1 body2 ...)
     (block tag
       (let rec ()
         body1 body2 ...
         (rec))))))
(define-syntax while
  (syntax-rules ()
    ((while test break continue body1 body2 ...)
     (block break
       (let loop ()
         (cond (test
                (block continue
                  body1 body2 ...)
                (loop))))))))
(define (atom? obj)
  (not (pair? obj)))
(define (find-if p lst)
  (cond ((null? lst) #f)
        ((p (car lst)) (car lst))
        (else (find-if p (cdr lst)))))
(define (append-atom lst obj)
  (append lst (list obj)))
(define (memoize proc)
  (let ((cache '()))
    (lambda args
      (let ((hit (assoc args cache)))
        (if hit (cdr hit)
            (let ((result (apply proc args)))
              (set! cache (cons (cons args result) cache))
              result))))))


(define (s-read file-name)
  (with-input-from-file file-name
    (lambda ()
      (let loop ((ls1 '()) (s (read)))
	(if (eof-object? s)
	    (reverse ls1)
	    (loop (cons s ls1) (read)))))))


;;http://stackoverflow.com/questions/1041603/how-do-i-write-push-and-pop-in-scheme
(define (list->stack lst) (box lst))
(define (stack-push! x a-list)
  (set-box! a-list (cons x (unbox a-list))))
(define (stack-pop! a-list)
  (let ((result (first (unbox a-list))))
    (set-box! a-list (rest (unbox a-list)))
    result))
(define (stack-top a-list) (first (unbox a-list)))
(define (stack-ref a-list n) (list-ref (unbox a-list) n))
(define (stack-set! a-list n v)
  (let ((lst (unbox a-list)))
    (set-box! 
     a-list
     (let loop ((i 0) (l1 '()) (l2 lst))
       (when (equal? i n)
	     (set! l2 (cons v (cdr l2))))
       (if (null? l2)
	   (reverse l1)
	   (loop (+ 1 i) (cons (car l2) l1 ) (cdr l2)))))))
(define (stack-set-apply! a-list n fn)
  (let ((lst (unbox a-list)))
    (set-box! 
     a-list
     (let loop ((i 0) (l1 '()) (l2 lst))
       (when (equal? i n)
	     (set! l2 (cons (fn (car l2))  (cdr l2))))
       (if (null? l2)
	   (reverse l1)
	   (loop (+ 1 i) (cons (car l2) l1 ) (cdr l2)))))))
(define (stack-map! fn a-list)
  (set-box! a-list (map fn (unbox a-list))))

;;;;; usage 
;; (define my-stack (box (list 1 2 3)))
;; (stack-push! 4 my-stack )
;; (stack-pop! my-stack)
;; (stack-top my-stack)
;; (stack-ref my-stack 0)
;; my-stack
;; (stack-set! my-stack 1 11)
;; (stack-set-fn! my-stack 1 (lambda (x) (+ 10 x)) )
;; (stack-map!  (lambda (x) (+ 10 x)) my-stack )

;; ;;;http://www.geocities.jp/m_hiroi/func/scheme02.html
;; (define (make-stack)
;;   (let ((front '()))
;;     (lambda (msg . args)
;;       (cond ((eq? msg 'push!)
;;              (set! front (cons (car args) front))
;;              (car args))
;;             ((eq? msg 'pop!)
;;              (if (null? front)
;;                  #f
;;                  (let ((data (car front)))
;;                    (set! front (cdr front))
;;                    data)))
;;             ((eq? msg 'empty?) (null? front))
;; 	    ;((eq? msg 'top
;;             (else #f)))))
;; ;;;;;usage 
;; ;; (define s (make-stack))
;; ;; (s 'push! 1)
;; ;; (s 'push! 2)
;; ;; (s 'pop!)



(define-macro (lstack-push! a lst)
  `(set! ,lst (cons ,a ,lst)))

;; (let ([l '(1 2 3)])
;;   (lstack-push! 4 l)
;;   l)


(define-macro (lstack-pop! lst)
  (let ([a (gensym)])
  `(let ([,a (car ,lst)])
     (set! ,lst (cdr ,lst)) ,a)))


;; (let ([l '(1 2 3)])
;;   (list (lstack-pop! l) l))


;; ;more close l1 l0 => #t
;; ;more close l2 l0 => #f
(define (list-similarity1-compare-from l0)
  (let ([ll0 (length l0)])
    (lambda (l1 l2)
      (cond 
       [(not (list? l1)) #f]
       [(not (list? l2)) #t]
       [else
	(let ([ll1 (length l1)][ll2 (length l2)])
	  (<
	   (abs (- ll1 ll0))
	   (abs (- ll2 ll0))
       ))]))))
    

;(length 0)
;(sort '((1 2) (1 2 3) (1 2 3 4 5) (1)) (lambda (l1 l2) (> (length l1) (length l2))))
;; => '((1 2 3 4 5) (1 2 3) (1 2) (1)) 
;; (sort '((1 2) 0 (1 2 3) (1 2 3 4 5) (1) 1 )  
;;       (list-similarity1-compare-from '(3 2)))
;; ;;=> '((1 2) (1 2 3) (1) (1 2 3 4 5) 0 1)

(define (list-correspond lst1 lst2)
  (let ((result '()))
    (let loop ((lst1 lst1)
	       (lst2 lst2))
      (cond ((null? lst1) (if (null? lst2) result '()))
	    ((pair? lst1)
	     (if (pair? (car lst1))
		 (loop (car lst1) (car lst2))
		 (begin
		   (set! result (cons (cons (car lst1) (car lst2)) result))
		   (loop (cdr lst1) (cdr lst2)))))
	    (else
	     (set! result (cons (cons lst1 lst2) result)))))
    result))

 

;; (list-correspond '(x (y z )) '(1 (a 3)))
;; (list-correspond '(x (y z )) '(1 3)) ;;=>'((z . _.0) (y . _.1) (x . 1) (3 _.1 _.0))

;; ;;=> '(((z . 3) (y . a) (x . 1)))
;; (list-correspond '(x . y) '(1 (a 3)))
;; (list-correspond '(x ) '(1 (a 3))) ;;fail '()


(define (vector-add x v) (vector-append (vector x) v))

;(vector-add 1 #(2 4))



(define (list-vset->vset-list lst)
  (define set? vector?)
  (define list->set list->vector)
  ;(define for/set for/vector)
  ;(define for*/set for*/vector)
  ;(define set-add vector-add)
  ;(define set-union vector-append)
  ;(define result '())
  (define (l2v l)
    (if (null? l) (list->set (list '()))
	(if (atom? l)
	    (if (set? l) l (list->set (list l)))
	    (begin
	      (
	      ;for*/set 
	      for*/vector
	      ([i (l2v (car l))]
	      [j (l2v (cdr l))])	     
	      ;(print (list i j))(newline)
	      (cons i j)
	      )))))
  (l2v lst)
  )

;; (atom? '())
;; (list-vset->vset-list #(1 2 4))
;; (list-vset->vset-list (list #(5 6) #(1 2 4))) 
;; (list-vset->vset-list '(11  #(5 6) ( #(1 2 4) ) )) 
;; =>'#((11 5 (1)) (11 5 (2)) (11 5 (4)) (11 6 (1)) (11 6 (2)) (11 6 (4)))
;; ;(atom? #(1 3))
;; (for*/vector 
;;  ([i #(1 2 4)]
;;   [j #( ())])
;;  (cons i j))

	
	


(define (call-with-values-ref f n) (call-with-values  f (lambda (x . y) (list-ref (cons x y ) n))))

;;(call-with-values-ref   (lambda () (values 1 2 3))  0)

(define (call-with-values-ref0 f) (call-with-values-ref  f 0))

;;(call-with-values-ref0   (lambda () (values 1 2 3)) )
	 

(define (call-with-values-ref-arg f n arg) 
  (call-with-values  (lambda () (apply f arg)) 
    (lambda (x . y) (list-ref (cons x y ) n))))

(define (call-with-values-ref0-arg f arg) 
  (call-with-values  (lambda () (apply f arg)) 
    (lambda (x . y) (list-ref (cons x y ) 0))))


;; (call-with-values-ref-arg (lambda (x y) (values x y)) 0 (list 1 2))
;; (call-with-values-ref0-arg (lambda (x y) (values x y)) (list 1 2))
	 
;; (apply (lambda (x y) (values x y)) (list 1 2 ))

;; (call-with-values  
;;     (lambda () (apply (lambda (x y) (values x y)) (list 1 2 )))
;;     ;(lambda (x . y) (list-ref (cons x y ) 1))
;;   +
;;     )




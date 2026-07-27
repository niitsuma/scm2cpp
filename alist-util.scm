#lang racket

(provide 
 alist-cons-update 

 alist-fn-update 
 alist-lset-union-eq-update
 alist-lset-union-equal-update

 alist-no-overwrite-update
 list-all-equal?


 vector-reverse
 vset-union
 vset-adjoin 
 alist-vset-union-eq-update
 alist-vset-union-equal-update

 lset-union-set!
 lset-adjoin-set!

)

(require srfi/1)






 ;;cl aconsrui
(define (alist-cons-update k v l)
  (if  (assoc k l)
       (if (equal? k (car  (car l)))
         (cons (cons k v)  (cdr l))
         (cons (car l)
	       (alist-cons-update k v  (cdr l))))
      (alist-cons  k v  l) ))

;;;;;usage 
;; (alist-cons-update 'a 10 '( ( b . 1) ( c  . 2)))   ;=> ((a . 10) (b . 1) (c . 2))
;; (alist-cons-update 'b 10 '( ( b . 1) ( c  . 2)))  ;=> ((b . 10) (c . 2)) 
;; (alist-cons-update 'b 10 '( ( b . 1)  (b .  8) ( c  . 2))) ;=> ((b . 10) (b . 8) (c . 2))
;; (alist-cons-update 'c 10 '( ( b . 1)  (b .  8) ( c  . 2)))  ;=> ((b . 1) (b . 8) (c . 10))


(define (alist-lset-union-eq-update k v l)
  (alist-fn-update k v l (lambda (x y) (lset-union eq? x y))))

(define (alist-lset-union-equal-update k v l)
  (alist-fn-update k v l (lambda (x y) (lset-union equal? x y))))

;; (define (alist-fn-update k v l fn)
;;   (if
;;    (assoc k l)
;;    (let loop ( (l0 '()) (l l))
;;      (let ([kv (car l)])
;;        (if
;; 	(eq? k (car kv))
;; 	(let ([ll (cons (cons k (fn (cdr kv) v)) (cdr l))])
;; 	  (if (null? l0)
;; 	      ll
;; 	      (cons (reverse l0) ll)))
;; 	(loop (cons kv l0)  (cdr l)))))
;;    (cons (cons k (fn '() v)) l)))

(define (alist-fn-update k v l fn)
  (if (null? l)
      (list (cons k (fn '() v)))
      (if (pair? l)
	  (let ([c (car l)][d (cdr l)])
	    (if (pair? c)
		(let ([cc (car c)][dc (cdr c)])
		  (if (eq? cc k)
		      (cons (cons cc (fn dc v)) d);;;apply fn later
		      (cons c
			    (alist-fn-update k v d fn))))
		(cons c
		      (alist-fn-update k v d fn))))
	  (cons (list (cons k (fn '() v))) l))))
	    
		

	

;; (alist-lset-union-eq-update 'a '(10) '( ( b . (1)) ( c  . (2)))) 
;; ;;=> '((a 10) (b 1) (c 2))

;; (alist-lset-union-eq-update 'b '(10 11) '( ( b . (1 3)) ( c  . (2)))) 
;; ;;=> '((b 11 10 1 3) (c 2))

;; (alist-lset-union-eq-update 'c '(10 11) '((a (2 1)) (x (3 1))  ( b . (1 3)) ( c  . (2 4)))) 
;; ;;=> '(((a (2 1)) (x (3 1)) (b 1 3)) (c 11 10 2 4))

;; (alist-lset-union-eq-update 'y '(s) '())
;; (alist-lset-union-eq-update 'y '(t) '((x . (v)) (y . (s))))
;; (alist-lset-union-eq-update 'x '(u) '((x . (v)) (y . (s t))))
;; (alist-lset-union-eq-update 'x '(u) '((y . (s))))
;; (alist-lset-union-eq-update 'x '(u) '((x . (v)) (y . (t s))))
;; (alist-lset-union-eq-update 'y '(t) '((x . (v)) (y . (s))))


(define (alist-no-overwrite-update k v l)
  (alist-fn-update k v l (lambda (x y) (if (null? x) y x)  )))


;; usage 
;; (alist-no-overwrite-update 'a 10 '( ( b . 1) ( c  . 2)))   ;=> ((a . 10) (b . 1) (c . 2))
;; (alist-no-overwrite-update 'b 10 '( ( b . 1) ( c  . 2)))  ;=> ((b . 1) (c . 2)) 
;; (alist-no-overwrite-update 'b 10 '( ( b . 1)  (b .  8) ( c  . 2))) ;=> ((b . 1) (b . 8) (c . 2))
;; (alist-no-overwrite-update 'c 10 '( ( b . 1)  (b .  8) ( c  . 2)))  ;=> ((b . 1) (b . 8) (c . 2))



(define (list-all-equal? tl)  (foldl (lambda (x y) (if (equal? x y) x #f)) (car tl) (cdr tl)))

;; (list-all-eq? '(a a a a))
;; (list-all-eq? '(a a b a))




;;;vector-set-util

(define (vector-reverse v) (list->vector (reverse (vector->list v))))
;(vector-reverse #(1 2 3 4))

(define (vset-union eq-fn . sets)
  (list->vector
   (apply lset-union `(,eq-fn ,@(map vector->list sets)))))

;(lset-union eq? '(a b c d e) '(a e i o u))
;(vset-union eq? #(a b c d e) #(a e i o u))
;(vset-union eq? #(a b c d e) #())
;(list->vector '())

(define (vset-adjoin eq-fn v . els)
  (list->vector
   (apply lset-adjoin `(,eq-fn ,(vector->list v) . ,els))))

;; (lset-adjoin eq? '(a b c d c e) 'a 'e 'i 'o 'u) ;=> (u o i a b c d c e)
;; (vset-adjoin eq? #(a b c d c e) 'a 'e 'i 'o 'u) ;=> (u o i a b c d c e)


(define (alist-vset-union-eq-update k v l)
  (if (assoc k l)
      (alist-fn-update k v l (lambda (x y) (vset-union eq? x y)))
      `( (,k . ,(vector-reverse v)) .  ,l)
      ))


(define (alist-vset-union-equal-update k v l)
  (if (assoc k l)
      (alist-fn-update k v l (lambda (x y) (vset-union equal? x y)))
      `( (,k . ,(vector-reverse v)) .  ,l)
      ))


;; ;(assoc 'a '( (a . 2) ))
;; (alist-vset-union-eq-update 'a  #(10) '( ( b . #(1)) ( c  . #(2)))) 
;; ;;=> '((a 10) (b 1) (c 2))
;; (alist-lset-union-eq-update 'b '(10 11) '( ( b . (1 3)) ( c  . (2)))) 
;; (alist-vset-union-eq-update 'b #(10 11) '( ( b . #(1 3)) ( c  . #(2)))) 
;; (alist-vset-union-eq-update 'b #(10) '( ( b . #(1)) ( c  . #(2)))) 
;; (alist-vset-union-eq-update 'b #(10) '( ( b . #(1)) ( c  . #(2 3)))) 

;; (alist-vset-union-eq-update 'x #(u) '( ( x . #(v)) ( y  . #(s t)))) 
;; (alist-vset-union-eq-update 'x (vector 'u) '( ( x . #(v)) ( y  . #(s t)))) 

;; ;;=> '((b 11 10 1 3) (c 2))
;; (alist-vset-union-eq-update 'c #(10 11) '((a #(2 1)) (x #(3 1))  ( b . #(1 3)) ( c  . #(2 4)))) 
;; (alist-lset-union-eq-update 'c '(10 11) '((a . (2 1)) (x . (3 1))  ( b . (1 3)) ( c  . (2 4)))) 
;; ;;=> '(((a (2 1)) (x (3 1)) (b 1 3)) (c 11 10 2 4))

;; (y s ((y . #(s))))
;; (x v ((x . #(v)) (y . #(s))))
;; (y t (((x . #(v))) (y . #(t s))))
;; (x u ((x . #(u)) ((x . #(v))) (y . #(t s))))

;; (alist-vset-union-eq-update 'x (vector 'u) '((x . #(v)) (y . #(t s))))
;; (alist-vset-union-eq-update 'y (vector 't) '((x . #(v)) (y . #(s))))



;; (y t (((x . #(v))) (y . #(t s))))
;; (x u 

;; (y s ((y . #(s))))
;; (x v ((x . #(v)) (y . #(s))))
;; (y t (((x . #(v))) (y . #(t s))))
;; (x u ((x . #(u)) ((x . #(v))) (y . #(t s))))
;; 1
;; '((x . #(u)) ((x . #(v))) (y . #(t s)))
;; '#()
;; '#()
;; '()



(require mzlib/defmacro)

(define-macro (lset-union-set! eqfn lst l1)
  `(set! ,lst (lset-union ,eqfn ,l1 ,lst)))

(define-macro (lset-adjoin-set! eqfn lst x)
  `(set! ,lst (lset-adjoin ,eqfn ,lst  ,x)))

#lang racket

(provide 

 ;op-num-num-num
 ;op-num-num-bool
 ;op-num-num
 ;op-num-bool

 type-symbols
 type-symbol-alist
 symbol-type-alist

 ctype-alist

 number-type-order-list
 number-type-base-name-order-list
 number-type-order-alist  
 number-prefix-alist

 compiler-tags

 operator-comparable-types

)


;(define op-num-num-num  '(+ - * / remainder))
;(define op-num-num-bool '( =  >  <  <= >=   ))
;(define op-num-num '(sub1 add1 ))
;(define op-num-bool '(zero?))

;(require srfi/1)
(require "alist-util.scm")
(require "alpha-conv.scm")
;(require "schlep-name.scm")
;(require "scm2cpp-function.scm")



(define type-symbols '())
;(define ctype-alist '())
(define type-symbol-alist null)
(define symbol-type-alist null)


 


(define-syntax define-type-symbol
  (syntax-rules ()
    ((_ 'x)
     (begin
       ;(display 'x)
       (define x (gensym 'x))
       (provide x)
       
       (let ((base-name
	      (string->symbol (string-downcase (symbol->string 'x )))))
	 (set! type-symbols
	       (append type-symbols (list x)))
	 (set! type-symbol-alist
	       (append type-symbol-alist 
		       (list (cons  x base-name))))
	 (set! symbol-type-alist
	       (append symbol-type-alist 
		       (list (cons base-name x))))
	 ;; (let ((base-name?-func-name  
	 ;; 	(string->symbol (string-append (symbol->string base-name ) "-symbol?"))))
	 ;;   (define-type-symbol?-func base-name?-func-name x) )

	   ;(define base-name?-func-name  
	 
	 )
       ))))

;(define-type-symbol 'ttttt)


(define-syntax define-type-symbol-list
  (syntax-rules ()
    (( _ '(e1)) (define-type-symbol 'e1))
    (( _ '(e1 e2 ...))
     (begin
       (define-type-symbol 'e1)
       (define-type-symbol-list '(e2 ...))
       )
     )
  ))


(define number-type-order-list null)
(define number-type-order-alist null)
(define number-type-base-name-order-list null)


(define-syntax define-number-type-symbol
  (syntax-rules ()
    ((_ 'x)
     (begin
       (define-type-symbol 'x)
       (let ((base-name
	      (string->symbol (string-downcase (symbol->string 'x )))))
	 (set! number-type-order-list 
	     (append number-type-order-list (list x) ))
	 (set! number-type-base-name-order-list 
	     (append number-type-base-name-order-list (list base-name) ))
	 (set! number-type-order-alist
	     (append number-type-order-alist (list (cons base-name x))))
       )))))



(define-syntax define-number-type-symbol-list
  (syntax-rules ()
    (( _ '(e1)) 
     (begin
       (define-number-type-symbol 'e1)
       ))
    (( _ '(e1 e2 ...))
     (begin
       (define-number-type-symbol 'e1)
       (define-number-type-symbol-list '(e2 ...))
       )
     )
  ))


;; (define-type-symbol-list 
;; '(Bool Short Int Rational Float Double Complex))
;; (define number-type-order-list
;;   (list 
;;    Bool Short Int Rational Float Double Complex))


(define-number-type-symbol-list 
   ;'(Bool Int Double))
   ;'(Bool Unsigned Short Int Rational Float Double Complex)
   ;'(Bool Int Rational Double Complex)
   ;'(Int Rational Double Complex)
   ;'(Number Int Rational Double Complex)
   '(Number Short Int Rational Float Double Complex)
;'(bool int float double complex number)
)


  

(define-type-symbol-list 
'(Void 
  Null
  Flags

  Mutable
  Const
  Referenced

  ValuesRef

  Funcall

  Bool
  ;Float  
  ;Bool Int Double 
  ;Number 
  Union Any
  Optional

  String Char Symbol
  Port 
  OStream IStream 
  Cons List Vector 

  FunctionReturns

  NoReturn

  Unknown
  NoType
  ExpandType
  Sexpr
  TypeMatchFail
))

;; (define number-type-order-list
;;   (list 
;;    Bool Int Double))
;;   ))
;; (define number-type-base-name-order-list 
;;   ;'(bool int float double complex number)
;;   '(bool int double)
;;   )
;; ;(define number-type-order-alist null)
;; (define number-type-order-alist 
;;   (Bool 




(define-syntax define-type-symbol?-func
  (syntax-rules ()
    ((_ 'x y)
     (begin
       (define x (lambda (s) (eq? s y)))
       (provide x)
     ))))

;; ;; (define-type-symbol?-func 'tmp-symbol? 'tmp)
;; ;; (tmp-symbol? 'tmp)

(define-syntax define-type-symbol?-func-list
  (syntax-rules ()
    (( _  `((e1 . ,s1))) (define-type-symbol?-func 'e1 s1))
    (( _  `((e1 . ,s1) e2 ...))
     (begin
       (define-type-symbol?-func 'e1 s1)
       (define-type-symbol?-func-list '(e2 ...))
       )
     )
  ))


(define-type-symbol?-func-list 
  `( 
    (union-symbol? . ,Union)
    (number-symbol? . ,Number)
    (bool-symbol? . ,Bool)
     )
  )

;; (define tmppp 'tmp)
;; (define aaaaa 'aaa)
;; (define bbbbb 'bbb)
;; (define-type-symbol?-func-list 
;;   `( 
;;     (tmp-symbol? . ,tmppp)
;;     (aaa-symbol? . ,aaaaa)
;;     (bbb-symbol? . ,bbbbb)
;;      )
;;   )
;; (tmp-symbol? 1)
;; (tmp-symbol? 'tmp)
;; (aaa-symbol? 1)
;; (aaa-symbol? 'aaa)
;; (bbb-symbol? 1)
;; (bbb-symbol? 'bbb)




(define number-prefix-alist 
  '(
    (char . u8)
    (short . s16)
    (int . s32)
    ;; (float . f32 )
    (float . f64 )
    (double . f64 )
    ))

;; (define uvect-types
;; '( 
;; s8vector	;signed exact integer in the range -(2^7) to (2^7)-1
;; u8vector	;unsigned exact integer in the range 0 to (2^8)-1
;; s16vector	;signed exact integer in the range -(2^15) to (2^15)-1
;; u16vector	;unsigned exact integer in the range 0 to (2^16)-1
;; s32vector	;signed exact integer in the range -(2^31) to (2^31)-1
;; u32vector	;unsigned exact integer in the range 0 to (2^32)-1
;; s64vector	;signed exact integer in the range -(2^63) to (2^63)-1
;; u64vector	;unsigned exact integer in the range 0 to (2^64)-1
;; ;There are 2 datatypes of inexact real homogeneous vectors (which will be called float vectors):
;; ;datatype	type of elements
;; f32vector	;inexact real
;; f64vector	;inexact real
;; ))

(define uvect-fix-length-types
  (map (lambda (x) (string->symbol (string-append (symbol->string x) "-fix-length" ))) uvect-types))


(define (number-type->uvect t)
  (let ((v  (assoc t  number-prefix-alist )))
    (if v (string->symbol (string-append (symbol->string (cdr v)) "vector"))
	'f64vector)))



(define compiler-tags 
  '(string
    char short int float double
    port 

    unknown 
    no-type
    expand-type
    sexpr
    type-match-fail
    inf
    inf-alist
    union
    subst ref
    

    ;;Homogeneous vector	      
    homo-vector homo-vector-fix-length homo-list homo-list-fix-length
    bool-vector bool-vector-fix-length
    homo-alist homo-alist-fix-length
    alist alist-fix-length
    
    lambda-export
    )
  )


(define operator-comparable-types
  (list 
   number-type-order-list
   ))
  



;; (let loop ([lst type-symbol-list])
;;   (display lst)
;;   (define-type-symbol x)  
;;   (when (not (null? lst))
;; 	(loop (cdr lst))))



;; (let loop ([x (car type-symbol-list)] [r (cdr type-symbol-list)]  )
;;   (define-type-symbol x)
;;   (when (not (null? r))
;; 	(loop (car r) (cdr r))))










(define ctype-alist `( 
		      ;(,Number . "double")  
		       (,Float . "double" )  
		       (,Double . "double" )  (,Int . "int" ) (,Bool . "bool" ) (,Char . "char" )  (,String . "std::string") (,Void . "void")) )


;; (define ctype-alist `( (,Number . "double")  (,Float . "double" )  (,Double . "double" )  (,Int . "int" ) (,Bool . "bool" ) (,Char . "char" )  (,String . "std::string")))

;; (define (type->ctype t )
;;   (let ((kv  (assq t ctype-alist)))
;;     (if kv (cdr kv)
;; 	(symbol->string t))))







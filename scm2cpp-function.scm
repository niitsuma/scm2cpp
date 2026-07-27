#lang racket

(provide 
 var-name-to-template-type-name 
 var-symbol-to-template-type-name
 function-args-names
 function-args-types

 function-name
 function-return-type
 function-return-args-types
 function-return-args-symbols
 function-return-args-names
 template-function?
 template-decltype-function?
 types-names->template-arg-str
 template-decltype-function-arg-str
 template-function-arg-str
 template-function-define-str 
 template-decltype-function-define-str
)


;(require "schlep-base.scm")
(require "schlep-name.scm")

;;add niitsuma
(define (var-name-to-template-type-name str)
  (let* (
	 (ar (map char-downcase (string->list str)))
	 (ar2 (cons (char-upcase (car ar)) (cdr ar)))
	 ) 
    (string-append (list->string ar2) "Type")    
))

(define (var-symbol-to-template-type-name var)
 (var-name-to-template-type-name (schlep-symbol-str var)))


(define (function-args-names sexp) (cdadr sexp))

;;;add niitsuma
(define (function-args-types sexp)  
  (let  ((func-args (cdadr sexp)))
    (if (null? func-args)
	'()	
	(map vartype (cdadr sexp))
	))
)


(define (function-name sexp) (caadr sexp))
(define (function-return-type sexp)(proctype (function-name sexp)))
(define (function-return-args-types sexp) (cons (function-return-type sexp) (function-args-types sexp)))
(define (function-return-args-symbols sexp) (cons (function-name sexp) (function-args-names sexp)))
(define (function-return-args-names sexp) (map schlep-symbol-str (function-return-args-symbols sexp)))
(define (template-function? sexp)(memq 'VAL  (function-return-args-types sexp)))
(define (template-decltype-function? sexp)(memq 'VAL  (function-args-types sexp)))

(define (types-names->template-arg-str types names)
    (string-join
     (filter string?
      (map
        (lambda (t n) 
          (when (eq? t VAL)
	     (string-append 
	      "typename " 
	      (var-name-to-template-type-name n))
		      )
	   ) types names))
     ","
     ))


(define (template-decltype-function-arg-str sexp) (types-names->template-arg-str  (function-args-types sexp) (map schlep-symbol-str (function-args-names sexp))))
(define (template-function-arg-str sexp) (types-names->template-arg-str (function-return-args-types sexp) (function-return-args-names sexp)))
(define (template-function-define-str sexp)  (string-append "template<"  (template-function-arg-str sexp)  ">"))
(define (template-decltype-function-define-str sexp)  (string-append "template<"  (template-decltype-function-arg-str sexp)  ">"))

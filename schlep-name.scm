#lang racket

(provide 
 assoc-if
 VOID
 VAL  
 ;LONG  
 BOOL
 INT 
;PTR ARRAY RETURN NONE COMMA SEMI SUBSCRIPT 
 declarations
 set!declarations
 declare-names
 declare-name!
 read-local-declarations
 read-version
 pragma.h
 pragma.c
 strip-quote
 __STDC__
 prototype-style
 ;declarations-report!
 schlep-name-str 
 schlep-name
 schlep-symbol-str
 schlep-symbol
 tmpify
 lblify
 vartype
 proctype
 type->exptype

 var-involved-except?
 var-involved?

 schlep-type2type
 alpha2declaratype
 alpha-declara->type-env
 alpha-free->type-env
 alpha-free->type-full-env
)



(require srfi/1)
(require srfi/13) ;string-index
(require srfi/59)

(require "schlep-base.scm")

(require "alpha-conv.scm")

(require "alist-util.scm")

;(require "type-infer-match.scm")

(include "slib-plt.scm")


(require "type-symbols.scm")
(require "list-util.scm")
(require "cl-util.scm")



(define translator 'scm2c)

;; ;; These are the possible values of @var{use} arguments to
;; ;; @code{schlep-exp}.
(define VOID 'VOID)
(define VAL 'VAL)
;; (define LONG 'LONG)
(define BOOL 'BOOL)

;; ;; These are types and type-modifiers which Schlep treats specially.
(define INT 'INT)
;; ;(define LONG 'LONG)
;; (define PTR 'PTR)
;; (define ARRAY 'ARRAY)

;; ;; These are the possible values of @var{termin} arguments to
;; ;; @code{schlep-exp}.
;; (define RETURN "return")
;; (define NONE "")
;; (define COMMA ",")
;; (define SEMI ";")
;; (define SUBSCRIPT "]")

(define declarations '())


;; ;;cl aconsrui
;; (define (alist-cons-update k v l)
;;   (if  (assoc k l)
;;       (if (equal? k (car  (car l)))
;;          (cons (cons k v)  (cdr l))
;;          (cons (car l)
;;               (alist-cons-update k v  (cdr l)))
;;      )
;;       (alist-cons  k v  l) 
;;       ))

;; ;;;;;usage 
;; ;; (alist-cons-update 'a 10 '( ( b . 1) ( c  . 2)))   ;=> ((a . 10) (b . 1) (c . 2))
;; ;; (alist-cons-update 'b 10 '( ( b . 1) ( c  . 2)))  ;=> ((b . 10) (c . 2)) 
;; ;; (alist-cons-update 'b 10 '( ( b . 1)  (b .  8) ( c  . 2))) ;=> ((b . 10) (b . 8) (c . 2))
;; ;; (alist-cons-update 'c 10 '( ( b . 1)  (b .  8) ( c  . 2)))  ;=> ((b . 1) (b . 8) (c . 10))


;;@noindent
;;These procedures can be mixed with code to be translated.

;;@body @1 must be a list of lists (declarations).  Glob
;;declarations may have local scope.  Glob declarations at
;;top level persist from one file to the next.
(define (declare-names globs)
  (for-each (lambda (glob)
	      (or (and (pair? glob)
		       (= 2 (length glob)))
		  (report "bad syntax" glob))
	      (declare-name! (car glob) (cadr glob)))
	    globs))


;;@noindent
;;The Scheme files in the table at@*
;;@url{http://people.csail.mit.edu/jaffer/CNS/benchmarks.html#PRNG}@*
;;have examples of the use of @code{declare-names}.

(define (declare-name! glob ctype) 
  ;;;;glob -> "*-ct"  ctype -> long  
  
  ;;;debug
  ;(display "declare-name!") 
  ;(display (list "declare-name!" glob ctype))  
  ;(display declarations)  
  
  (when (symbol? glob) (set! glob (symbol->string glob)))
  (let (	      ; CADDR is count per file, CADDDR is cumulative.
	(entry (list (filename:match?? glob) glob ctype 0 0)))
    (let loop ((typs declarations))
      (cond ((null? typs)
	     (set! declarations (append declarations (list (list entry)))))
	    (else
             ;;;racket neeed mod : car -> mcar cdr->mcdr cons->mcons
             
	     ;(set-cdr! typs (mcons (mcar typs) (mcdr typs)))
	     ;(set-car! typs (list entry))
             
             (set! declarations (cons (list entry) (cons (car typs) (cdr typs) )))
             
             )))))



(define (read-local-declarations vic)
  (let ((typfile
	 (in-vicinity vic (string-append (symbol->string translator) ".typ"))))
    (cond ((file-exists? typfile)
	   (set! declarations '())
	   (display "Reading type declarations from ")
	   (display typfile)
	   (newline)
	   (declare-names (call-with-input-file typfile read))
	   #t)
	  (else #f))))



(define (read-version revfile)
  (and (file-exists? revfile)
       (call-with-input-file
	   revfile (lambda (port)
		     (and (find-string-from-port? "VERSION" port)
			  (read port))))))

;;@node Target Language, Schlpe API, Delcarations, Top
;;@chapter Target Language

;;@body In Scheme source, @0 has no effect, but the @1 are written to
;;@var{filename}.h during translation.
(define (pragma.h . strings) #f)

;;@body In Scheme source, @0 has no effect, but the @1 are written to
;;@var{filename}.c during translation.
(define (pragma.c . strings) #f)

(define (strip-quote expr)
  (if (and (pair? expr) (eq? 'quote (car expr)))
      (cadr expr)
      expr))

;;mod plt-scheme
;;(defvar __STDC__ #t)
(define __STDC__ #t)


;;@body Sets the type of prototypes written to the .h files.  Make @1
;;the symbol STDC for ANSI function prototypes; SCM for SCM
;;conditional prototypes; NIL for K&R C.  The default value is STDC.
(define (prototype-style style)
  (set! __STDC__
	(case style
	  ((NIL () #f) #f)
	  ((__STDC__ STDC) #t)
	  ((SCM) 'SCM))))

;;@
;;To work with the conditional prototypes, an include file loaded
;;before the Schlepped .h files should contain:
;;@w{@code{#include "@url{schleprt.h}"}}
;;
;;@w{@code{#include "@url{schleprt.h}"}} or its content may also be
;;needed if your code uses @code{min}, @code{max}, non-stack
;;allocations, or the diagnostic output routines @code{dprintf},
;;@code{wdprintf}, or @code{edprintf}.  If you use the diagnostic
;;output routines, you must also define diagout.  The file
;;"@url{schleprt.c}" does this; its entire content is:
;;
;;@example
;; #include <stdio.h>
;; FILE *diagout;
;;@end example

;; @body Returns a string describing the current input-file and
;; line-number, if that information is known.  @0 would only be useful
;; as a read-macro in the file being translated:
;;
;; @example
;; #.(where)
;; @end example
;; (define (where)
;;   (string-append (or (port-filename *schlep-input*)
;; 		     *schlep-input-name*)
;; 		 ":"
;; 		 (cond ((port-line *schlep-input*) => number->string)
;; 		       (else "??"))
;; 		 ": "))

;;These variables control file translation.  They have no effect from
;;the file being translated, unless they are defined using
;;read-macros: @code{#.(define number-lines? #t)}.

;;@body
;;Define @0 to #t for C code to be prefixed with commmented line
;;numbers.  The default value is #f.
;;(defvar number-lines? #f)
;;mod plt-scheme
;(define number-lines? #f)


;; ;;@body Prints an association-list (suitable passing to
;; ;;@code{declare-name!}) along with the counts of references to each
;; ;;name pattern type declared.
;; (define (declarations-report! cumulative? port)
;;   (define cum-uses cadddr)
;;   (define set-cum-uses! (lambda (arg n) (set-car! (cdddr arg) n)))
;;   (define file-uses caddr)
;;   (define set-file-uses! (lambda (arg n) (set-car! (cddr arg) n)))
;;   (cond ((string? port)
;; 	 (call-with-output-file port
;; 	   (lambda (port)
;; 	     (declarations-report! cumulative? port))))
;; 	(cumulative?
;; 	 (fprintf port ";; ~a.typ\n" translator)
;; 	 (display "(" port)
;; 	 (for-each (lambda (arg)
;; 		     (set! arg (cdr arg))
;; 		     (let ((uses (+ (cum-uses arg)
;; 				    (file-uses arg))))
;; 		       (cond ((positive? uses)
;; 			      (fprintf port "\n (%#-6a %#-20a)"
;; 				       (car arg) (cadr arg))
;; 			      (set-cum-uses! arg 0)
;; 			      (set-file-uses! arg 0)
;; 			      (fprintf port " ;; %d uses" uses)))))
;; 		   (reverse (apply append declarations)))
;; 	 (display "\n )\n" port))
;; 	(else
;; 	 (fprintf port
;;                   ;"#+%s\n" 
;;                   "#+~s\n" 
;;                   translator)
;; 	 (display "(declare-names" port)
;; 	 (for-each (lambda (arg)
;; 		     (set! arg (cdr arg))
;; 		     (let ((uses (file-uses arg)))
;; 		       (cond ((positive? uses)
;; 			      (fprintf port "\n (%#-6a %#-20a)"
;; 				       (car arg) (cadr arg))
;; 			      (set-file-uses! arg 0)
;; 			      (set-cum-uses! arg (+ (cum-uses arg) uses))
;; 			      (fprintf port " ;; %d uses" uses)))))
;; 		   (reverse (apply append declarations)))
;; 	 (display "\n )\n" port))))

;;;--------other part from scm2c.scm--

;; Removes or translates characters from @1 and displays to @2
(define (schlep-name-str name)
  (call-with-output-string (lambda (port) (schlep-name name port) ))
)


(define (schlep-name name port)
  (define visible? #f)
  (define last-c #f)
  (for-each
   (lambda (c)
     (let ((tc (cond ((char-alphabetic? c) c)
		     ((char-numeric? c) c)
		     ((char=? c #\%) "_Percent")
		     ((char=? c #\@) "_At")
		     ((char=? c #\=) "_equal")
		     ((char=? c #\<) "_less")
		     ((char=? c #\>)
		      (cond ((eqv? #\- last-c) "to_")
			    (else "_more")))
		     ((char=? c #\:) #\_)
		     ((char=? c #\-) #\_)
		     ((char=? c #\_) #\_)
		     ((char=? c #\?) "_P")
		     ((char=? c #\.) "_")
		     (else #f))))
       (cond (tc (set! visible? #t) (display tc port)))
       (set! last-c c)))
   (string->list name))
  (when (not visible?) (report "C-invisible symbol?" name)))

(define (schlep-symbol-str name)
  (call-with-output-string (lambda (port) (schlep-symbol name port) ))
)


(define (schlep-symbol name port)
  (case name
;;;     ((string=?) (display "string_equal_P" port))
;;;     ((string>?) (display "string_more_P" port))
;;;     ((string>=?) (display "string_more_equal_P" port))
;;;     ((string<?) (display "string_less_P" port))
    (else
     (schlep-name (symbol->string name) port))))

;; Makes a temporary variable name.
(define (tmpify sym)
  (string->symbol (string-append "T_" (symbol->string sym))))

;; Makes a label name.
(define (lblify sym)
  (string->symbol (string-append "L_" (symbol->string sym))))

(define (assoc-if str alst)
  (cond ((null? alst) #f)
	(((caar alst) str) (car alst))
	(else (assoc-if str (cdr alst)))))

;;; VARTYPE gives a guess for the type of var
;;; result is symbol: INT ARRAY and so on
(define (vartype var)
  (define (suffix->ctype str len)
    (let loop ((typs declarations))
      (and (pair? typs)
	   (let* ((match (assoc-if (substring str 0 len) (car typs))))
	     (cond (match

                       ;;;; replace set-car!                       
                    ;(set! match (cdr match))
		    ;(set-car! (cddr match) (+ 1 (caddr match)))
                      (let ((match-tmp  (cdr match)))                        
                        (set! match 
                             (cons (+ 1 (caddr match-tmp))                         
                                  (cdr match-tmp) )))
                     
		    match)
		   (else
		    (loop (cdr typs))))))))

  (let* ((str (symbol->string var))
	 (len (string-length str)))
    (do ((i len (+ -1 i)))
	((not (char-numeric? (string-ref str (+ -1 i)))) (set! len i)))
    (cond ((eqv? 0 (substring? "T_" str))
	   (set! str (substring str 2 len))
	   (set! len (+ -2 len))))
    (let ((v (suffix->ctype str len)))
      (cond 
       ;; [(and (not v) (char=? #\? (string-ref str (+ -1 len)))) 
       ;; 	     BOOL
       ;; 	     ]
       ((not v) 
	     ;'INT ;other type is int
	     'VAL ;other type is int
	     ) 
       ((and (memq (cadr v) '(ARRAY PTR)) (>= len 4))
	(let ((c (string-ref str (- len 4))))
	  (list (cadr v)
		(vartype (string->symbol
			  (substring str 0
				     (if (memv c '(#\- #\: #\_))
					 (- len 4)
					 (- len 3))))))))
       ((and (eq? (cadr v) 'word)
	     (>= len 5)
	     (string-ci=? "dword" (substring str (+ -5 len) len)))
	'dword)
       ((cadr v) (cadr v))
       ;(else INT) ;other type is int
       [else 'VAL]
))))

;; ;;; PROCTYPE - gives a guess for the type of proc
;; (define (proctype proc)
;;   (let ((str (symbol->string proc)))
;;     (case (string-ref str (- (string-length str) 1))
;;       ((#\?) BOOL)
;;       ((#\!) VOID)
;;       (else (or (vartype proc)
;; 		(begin (report "unknown type" proc)
;; 		       VAL))))))

;;; PROCTYPE - gives a guess for the type of proc
(define (proctype proc)
  (or (vartype proc)
      (begin (report "unknown type" proc)
	     VAL))
  )


(define (type->exptype type)
  (case type
    ((VOID BOOL LONG) type)
    (else VAL)))


;;;--------other part from scm2c.scm--

(define (var-involved-except? var sexps own)
  (if (null? sexps) #f
      (if (eq? (car sexps) own)
	  (var-involved-except? var (cdr sexps) own)
	  (or (var-involved? var (car sexps))
	      (var-involved-except? var (cdr sexps) own)))))

(define (var-involved? var sexp)
  (if (pair? sexp)
      (or (var-involved? var (car sexp))
	  (var-involved? var (cdr sexp)))
      (eq? sexp var)))

;------interface 
(define (set!declarations x)
  (set! declarations x))

;------with alpha



(define (schlep-type2type t)
  (if (pair? t)
      (cons
       (schlep-type2type (car t))
       (schlep-type2type (cdr t)))
      (case t 
	((BOOL) 'bool)
	((INT) 'int)
	(else t)
	)))
;; ;;;;;;debug
;; (schlep-type2type 'BOOL) ;bool
;; (schlep-type2type 'double) ;double
;; (schlep-type2type '(ARRAY (ARRAY BOOL))) ;'(ARRAY (ARRAY bool))


(define (alpha2declaratype alpha)
  (map 
   (lambda (xy) 
     (cons 
      (car xy) 
          (proctype (cdr xy))))   
   alpha
  ))  

(define (alpha-declara->type-full-env  alpha)
  (map
   (lambda (xy) 
     (if 
      (or 
       (equal? (cdr xy) 'VAL)
       (equal? (cdr xy) 'val))
      (cons (car xy) (car xy) )
      xy))
   (alpha2declaratype alpha)
))

(define (alpha-declara->type-env  alpha)
  (filter 
   (lambda (xy) 
     (not
      (or 
       (equal? (cdr xy) 'VAL)
       (equal? (cdr xy) 'val))))
   (alpha2declaratype alpha)
))



(define (alpha-free->type-env  alpha free)
  (append 
   (alpha-declara->type-env  alpha)
   (alpha-declara->type-env  free)))

(define (alpha-free->type-full-env  alpha free)
  (append 
   (alpha-declara->type-full-env  alpha)
   (alpha-declara->type-full-env  free)))




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
;; (exp-alpha-free->init-type-full-env debug-alpha debug-free debug-exp)



;(proctype 'x)


;; (define (alpha-type-mod 


;; ;;;-------------debug-------------------

;; (set!declarations '())

;; (display (call-with-input-file "scm2c.typ" read))

;; ;;;;manual set declarations
;; (declare-names '( 
;;                 ("*matrix" (ARRAY (ARRAY double)))   
;;                 ("*str"  (ARRAY "unsigned char")   ) 
;;                 ("*mat" "boost::ublas::matrix")
;;                 ) 
;;             )

;; ;;;;file set declarations
;; (declare-names  (call-with-input-file "scm2c.typ" read)) 

;; ;;;;str declarationstr  set declarations
;; (declare-names 
;;  (call-with-input-string 
;;   declarationstr
;;   (lambda (p) (read p))))                     

;; (display declarations)


;; ;;;type infer from    declarations                   
;; (vartype 'x-int)
;; (vartype 'x-matrix)
;; (vartype 'set!) ;; VAL
;; (proctype 'set!) ;;VOID
;; (proctype 'number?) ;; BOOL
;; (proctype 'f-int)
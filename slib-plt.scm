;#lang racket
;;; defmacro, macroexpand, ... ) for Racket.
;;; SLIB is by Aubrey Jaffer:  https://people.csail.mit.edu/jaffer/SLIB
;;;
;;; Copyright (C) 1991-2006 Aubrey Jaffer and Radey Shouman
;;; Copyright (C) 2008, 2009 Aubrey Jaffer
;
;Permission to copy this software, to modify it, to redistribute it,
;to distribute modified versions, and to use it for any purpose is
;granted, subject to the following restrictions and understandings.
;
;1.  Any copy made of this software must include this copyright notice
;in full.
;
;2.  I have made no warranty or representation that the operation of
;this software will be error-free, and I am under no obligation to
;provide any services, by way of maintenance, update, or otherwise.
;
;3.  In conjunction with products arising from the use of this
;material, there shall be no use of my name in any advertising,
;promotional, or sales literature without prior written consent in
;each case.
;
;;; Adaptation for Racket: Copyright (C) 2011-2026 Hirotaka Niitsuma

;(require srfi/13) ;string-index
;(require srfi/59)

;(require racket/include)
;;(require r5rs) ;for else in cond and set-cdr!
;(require rnrs/mutable-pairs-6);set-cdr!
;(require mzlib/etc)
;(require mzlib/defmacro)

;(require  compiler/zo-parse)

;;;compat plt and SCM

;(require mzscheme)
;(require r5rs) ;for else in cond





;; http://www.gnu.org/software/guile/manual/html_node/Characters.html
;;(define	#(J\(Bnl #(J\(Bnewline )
;;(define-macro #(J\(Bnl #(J\(Bnewline  )
;;(define #(J\(Bcr #(J\(Breturn)

;http://people.csail.mit.edu/jaffer/scm_4.html
;(define (try-open-file))
;;need mod for racket

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;"mzscheme.init" Initialization for SLIB for mzscheme	-*-scheme-*-

;;@ define an error procedure for the library
(define (slib:error)
  (display "Error:")
  ;; (let ((error error))
  ;;   (lambda args
  ;;     (let ((cep (current-error-port)))
  ;; 	(if (provided? 'trace) (print-call-stack cep))
  ;; 	(apply error  args))))
)

(define slib:tab #\tab)
;(define slib:tab (integer->char 9))

(define char-code-limit 256)



;;; slib:features should be set to a list of symbols describing
;;; features of this implementation.  Suggestions for features are:

(define slib:features
      '(
	source				;can load scheme source files
					;(slib:load-source "filename")
	compiled			;can load compiled files
					;(slib:load-compiled "filename")
	rev4-report			;conforms to
;;;	rev3-report			;conforms to
;;;	ieee-p1178			;conforms to
;;;	srfi-0				;srfi-0, COND-EXPAND finds all srfi-*
;;;	sicp				;runs code from Structure and
					;Interpretation of Computer
					;Programs by Abelson and Sussman.
	rev4-optional-procedures	;LIST-TAIL, STRING->LIST,
					;LIST->STRING, STRING-COPY,
					;STRING-FILL!, LIST->VECTOR,
					;VECTOR->LIST, and VECTOR-FILL!
;;;	rev2-procedures			;SUBSTRING-MOVE-LEFT!,
					;SUBSTRING-MOVE-RIGHT!,
					;SUBSTRING-FILL!,
					;STRING-NULL?, APPEND!, 1+,
					;-1+, <?, <=?, =?, >?, >=?
	multiarg/and-			;/ and - can take more than 2 args.
	multiarg-apply			;APPLY can take more than 2 args.
	rationalize
	delay				;has DELAY and FORCE
	with-file			;has WITH-INPUT-FROM-FILE and
					;WITH-OUTPUT-FROM-FILE
	string-port			;has CALL-WITH-INPUT-STRING and
					;CALL-WITH-OUTPUT-STRING
;;;	transcript			;TRANSCRIPT-ON and TRANSCRIPT-OFF
	char-ready?
	macro				;has R4RS high level macros
	syntax-case			;has syntax-case macros
	defmacro			;has Common Lisp DEFMACRO
	eval				;SLIB:EVAL is single argument eval
;;;	record				;has user defined data structures
	values				;proposed multiple values
	dynamic-wind			;proposed dynamic-wind
	ieee-floating-point		;conforms to
	full-continuation		;can return multiple times
;;;	object-hash			;has OBJECT-HASH

;;;	Sort
;;;	queue				;queues
	pretty-print
;;;	object->string
	format				;plt/collects/srfi/28.ss says in core
;;;	trace				;has macros: TRACE and UNTRACE
;;;	compiler			;has (COMPILER)
;;;	ed				;(ED) is editor
	system				;posix (system <string>)
	getenv				;posix (getenv <string>)
	program-arguments		;returns list of strings (argv)
;;;	Xwindows			;X support
;;;	curses				;screen management package
;;;	termcap				;terminal description package
;;;	terminfo			;sysV terminal description
	fluid-let
	srfi-59
	srfi-96
	vicinity
	current-time			;returns time in seconds since 1/1/1970
	))
;@

;;@ SLIB:EVAL is single argument eval using the top-level (user) environment.
(define slib:eval eval)

(define *defmacros*
  (list (cons 'defmacro
	      (lambda (name parms . body)
		`(set! *defmacros* (cons (cons ',name (lambda ,parms ,@body))
					 *defmacros*))))))

;@
(define (defmacro? m) (and (assq m *defmacros*) #t))
;@
(define (macroexpand-1 e)
  (if (pair? e)
      (let ((a (car e)))
	(cond ((symbol? a) (set! a (assq a *defmacros*))
	       (if a (apply (cdr a) (cdr e)) e))
	      (else e)))
      e))
;@
(define (macroexpand e)
  (if (pair? e)
      (let ((a (car e)))
	(cond ((symbol? a)
	       (set! a (assq a *defmacros*))
	       (if a (macroexpand (apply (cdr a) (cdr e))) e))
	      (else e)))
      e))

;@
(define gentemp
  (let ((*gensym-counter* -1))
    (lambda ()
      (set! *gensym-counter* (+ *gensym-counter* 1))
      (string->symbol
       (string-append "slib:G" (number->string *gensym-counter*))))))

;;;(define base:eval slib:eval)
;@
;;;(define (defmacro:eval x) (base:eval (defmacro:expand* x)))
;;(define (defmacro:expand* x)
;;;  ;;(slib:require 'defmacroexpand) 
;;;  (apply defmacro:expand* x '())
;;;)
;@



;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;"defmacex.scm" defmacro:expand* for any Scheme dialect.

(define (defmacro:iqq e depth)
  (letrec
      ((map1 (lambda (f x)
	       (if (pair? x) (cons (f (car x)) (map1 f (cdr x)))
		   x)))
       (iqq (lambda (e depth)
	      (if (pair? e)
		  (case (car e)
		    ((quasiquote) (list (car e) (iqq (cadr e) (+ 1 depth))))
		    ((unquote unquote-splicing)
		     (list (car e) (if (= 1 depth)
				       (defmacro:expand* (cadr e))
				       (iqq (cadr e) (+ -1 depth)))))
		    (else (map1 (lambda (e) (iqq e depth)) e)))
		  e))))
    (iqq e depth)))
;@
(define (defmacro:expand* e)
  (if (pair? e)
      (let* ((c (macroexpand e)))
	(if (not (eq? e c))
	    (defmacro:expand* c)
	    (case (car e)
	      ((quote) e)
	      ((quasiquote) (defmacro:iqq e 0))
	      ((lambda define set!)
	       (cons (car e) (cons (cadr e) (map defmacro:expand* (cddr e)))))
	      ((let)
	       (let ((b (cadr e)))
		 (if (symbol? b)	;named let
		     `(let ,b
			,(map (lambda (vv)
				`(,(car vv)
				  ,(defmacro:expand* (cadr vv))))
			      (caddr e))
			,@(map defmacro:expand*
			       (cdddr e)))
		     `(let
			  ,(map (lambda (vv)
				  `(,(car vv)
				    ,(defmacro:expand* (cadr vv))))
				b)
			,@(map defmacro:expand*
			       (cddr e))))))
	      ((let* letrec)
	       `(,(car e) ,(map (lambda (vv)
				  `(,(car vv)
				    ,(defmacro:expand* (cadr vv))))
				(cadr e))
			  ,@(map defmacro:expand* (cddr e))))
	      ((cond)
	       `(cond
		 ,@(map (lambda (c)
			  (map defmacro:expand* c))
			(cdr e))))
	      ((case)
	       `(case ,(defmacro:expand* (cadr e))
		  ,@(map (lambda (c)
			   `(,(car c)
			     ,@(map defmacro:expand* (cdr c))))
			 (cddr e))))
	      ((do)
	       `(do ,(map
		      (lambda (initsteps)
			`(,(car initsteps)
			  ,@(map defmacro:expand*
				 (cdr initsteps))))
		      (cadr e))
		    ,(map defmacro:expand* (caddr e))
		  ,@(map defmacro:expand* (cdddr e))))
	      ((defmacro)
	       (cons (car e)
		     (cons (cadr e)
			   (cons (caddr e) (map defmacro:expand* (cdddr e))))))
	      (else (map defmacro:expand* e)))))
      e))










;;;;;;;;;;;;;;;;;;;;;;;;;;
;"fluidlet.scm", FLUID-LET for Scheme

;; ;@
;; (defmacro fluid-let (clauses . body)
;;   (let ((ids (map car clauses))
;; 	(new-tmps (map (lambda (x) (gentemp)) clauses))
;; 	(old-tmps (map (lambda (x) (gentemp)) clauses)))
;;     `(let (,@(map list new-tmps (map cadr clauses))
;; 	   ,@(map list old-tmps (map (lambda (x) #f) clauses)))
;;        (dynamic-wind
;; 	   (lambda ()
;; 	     ,@(map (lambda (ot id) `(set! ,ot ,id))
;; 		    old-tmps ids)
;; 	     ,@(map (lambda (id nt) `(set! ,id ,nt))
;; 		    ids new-tmps))
;; 	   (lambda () ,@body)
;; 	   (lambda ()
;; 	     ,@(map (lambda (nt id) `(set! ,nt ,id))
;; 		    new-tmps ids)
;; 	     ,@(map (lambda (id ot) `(set! ,id ,ot))
;; 		    ids old-tmps))))))


(define-syntax fluid-let
  (lambda(x)
    (syntax-case x ()
      ((_ ((var obj) ...) body ...)
       (with-syntax
           (((temp ...)
             (generate-temporaries (syntax (var ...)))))
         (syntax
          (let ((temp var) ...)
            (dynamic-wind
                (lambda() (set! var obj) ...)
                (lambda() body ...)
                (lambda() (set! var temp) ...)))))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;
;;strsrch.scm

;;;@ Return the index of the first occurence of chr in str, or #f
;; (define (string-index str chr)
;;   (define len (string-length str))
;;   (do ((pos 0 (+ 1 pos)))
;;       ((or (>= pos len) (char=? chr (string-ref str pos)))
;;        (and (< pos len) pos))))


;@
(define (substring? pat str)
  (define patlen (string-length pat))
  (define strlen (string-length str))
  (cond ((zero? patlen) 0)		; trivial match
	((>= patlen strlen) (and (= patlen strlen) (string=? pat str) 0))
	;; use faster string-index to match a single-character pattern
	((= 1 patlen) (string-index str (string-ref pat 0)))
	((or (<= strlen (+ patlen patlen (quotient char-code-limit 2)))
	     (<= patlen 4))
	 (subloop pat patlen str strlen char=?))
	(else
	 ;; compute skip values for search pattern characters
	 ;; for all c not in pat, skip[c] = patlen + 1
	 ;; for c in pat, skip[c] is distance of rightmost occurrence
	 ;;  of c from end of str
	 (let ((skip (make-vector char-code-limit (+ patlen 1))))
	   (do ((i 0 (+ i 1)))
	       ((= i patlen))
	     (vector-set! skip (char->integer (string-ref pat i))
			  (- patlen i)))
	   (subskip skip pat patlen str strlen char=?)))))

(define (subskip skip pat patlen str strlen char=)
  (do ((k patlen (if (< k strlen)
		     (+ k (vector-ref skip (char->integer (string-ref str k))))
		     (+ strlen 1))))
      ((or (> k strlen)
	   (do ((i 0 (+ i 1))
		(j (- k patlen) (+ j 1)))
	       ((or (= i patlen)
		    (not (char= (string-ref pat i) (string-ref str j))))
		(= i patlen))))
       (and (<= k strlen) (- k patlen)))))


;;; Assumes that PATLEN > 1
(define (subloop pat patlen str strlen char=)
  (define span (- strlen patlen))
  (define c1 (string-ref pat 0))
  (define c2 (string-ref pat 1))
  (let outer ((pos 0))
    (cond
     ((> pos span) #f)		; nothing was found thru the whole str
     ((not (char= c1 (string-ref str pos)))
      (outer (+ 1 pos)))	; keep looking for the right beginning
     ((not (char= c2 (string-ref str (+ 1 pos))))
      (outer (+ 1 pos)))	 ; could've done pos+2 if c1 == c2....
     (else			  ; two char matched: high probability
					; the rest will match too
      (let inner ((pdx 2) (sdx (+ 2 pos)))
	(if (>= pdx patlen) pos	; the whole pat matched
	    (if (char= (string-ref pat pdx)
		       (string-ref str sdx))
		(inner (+ 1 pdx) (+ 1 sdx))
		;; mismatch after partial match
		(outer (+ 1 pos)))))))))
;@
(define (find-string-from-port? str <input-port> . max-no-char)
  (set! max-no-char (if (null? max-no-char) #f (car max-no-char)))
  (letrec
      ((no-chars-read 0)
       (peeked? #f)
       (my-peek-char			; Return a peeked char or #f
	(lambda () (and (or (not (number? max-no-char))
			    (< no-chars-read max-no-char))
			(let ((c (peek-char <input-port>)))
			  (cond (peeked? c)
				((eof-object? c) #f)
				((procedure? max-no-char)
				 (set! peeked? #t)
				 (if (max-no-char c) #f c))
				((eqv? max-no-char c) #f)
				(else c))))))
       (next-char (lambda () (set! peeked? #f) (read-char <input-port>)
			  (set! no-chars-read  (+ 1 no-chars-read))))
       (match-1st-char			; of the string str
	(lambda ()
	  (let ((c (my-peek-char)))
	    (and c
		 (begin (next-char)
			(if (char=? c (string-ref str 0))
			    (match-other-chars 1)
			    (match-1st-char)))))))
       ;; There has been a partial match, up to the point pos-to-match
       ;; (for example, str[0] has been found in the stream)
       ;; Now look to see if str[pos-to-match] for would be found, too
       (match-other-chars
	(lambda (pos-to-match)
	  (if (>= pos-to-match (string-length str))
	      no-chars-read	       ; the entire string has matched
	      (let ((c (my-peek-char)))
		(and c
		     (if (not (char=? c (string-ref str pos-to-match)))
			 (backtrack 1 pos-to-match)
			 (begin (next-char)
				(match-other-chars (+ 1 pos-to-match)))))))))

       ;; There had been a partial match, but then a wrong char showed up.
       ;; Before discarding previously read (and matched) characters, we check
       ;; to see if there was some smaller partial match. Note, characters read
       ;; so far (which matter) are those of str[0..matched-substr-len - 1]
       ;; In other words, we will check to see if there is such i>0 that
       ;; substr(str,0,j) = substr(str,i,matched-substr-len)
       ;; where j=matched-substr-len - i
       (backtrack
	(lambda (i matched-substr-len)
	  (let ((j (- matched-substr-len i)))
	    (if (<= j 0)
		;; backed off completely to the begining of str
		(match-1st-char)
		(let loop ((k 0))
		  (if (>= k j)
		      (match-other-chars j) ; there was indeed a shorter match
		      (if (char=? (string-ref str k)
				  (string-ref str (+ i k)))
			  (loop (+ 1 k))
			  (backtrack (+ 1 i) matched-substr-len))))))))
       )
    (match-1st-char)))
;@

;;;;;;;;;;;;;;;;;;;;;;;;;;




;;slib:glob

(define (glob:pattern->tokens pat)
  (cond
   ((string? pat)
    (let loop ((i 0)
	       (toks '()))
      (if (>= i (string-length pat))
	  (reverse toks)
	  (let ((pch (string-ref pat i)))
	    (case pch
	      ((#\? #\*)
	       (loop (+ i 1)
		     (cons (substring pat i (+ i 1)) toks)))
	      ((#\[)
	       (let ((j
		      (let search ((j (+ i 2)))
			(cond
			 ((>= j (string-length pat))
			  (slib:error 'glob:make-matcher
				      "unmatched [" pat))
			 ((char=? #\] (string-ref pat j))
			  (if (and (< (+ j 1) (string-length pat))
				   (char=? #\] (string-ref pat (+ j 1))))
			      (+ j 1)
			      j))
			 (else (search (+ j 1)))))))
		 (loop (+ j 1) (cons (substring pat i (+ j 1)) toks))))
	      (else
	       (let search ((j (+ i 1)))
		 (cond ((= j (string-length pat))
			(loop j (cons (substring pat i j) toks)))
		       ((memv (string-ref pat j) '(#\? #\* #\[))
			(loop j (cons (substring pat i j) toks)))
		       (else (search (+ j 1)))))))))))
   ((pair? pat)
    (for-each (lambda (elt) (or (string? elt)
				(slib:error 'glob:pattern->tokens
					    "bad pattern" pat)))
	      pat)
    pat)
   (else (slib:error 'glob:pattern->tokens "bad pattern" pat))))




(define (glob:make-matcher pat ch=? ch<=?)
  (define (match-end str k kmatch)
    (and (= k (string-length str)) (reverse (cons k kmatch))))
  (define (match-str pstr nxt)
    (let ((plen (string-length pstr)))
      (lambda (str k kmatch)
	(and (<= (+ k plen) (string-length str))
	     (let loop ((i 0))
	       (cond ((= i plen)
		      (nxt str (+ k plen) (cons k kmatch)))
		     ((ch=? (string-ref pstr i)
			    (string-ref str (+ k i)))
		      (loop (+ i 1)))
		     (else #f)))))))
  (define (match-? nxt)
    (lambda (str k kmatch)
      (and (< k (string-length str))
	   (nxt str (+ k 1) (cons k kmatch)))))
  (define (match-set1 chrs)
    (let recur ((i 0))
      (cond ((= i (string-length chrs))
	     (lambda (ch) #f))
	    ((and (< (+ i 2) (string-length chrs))
		  (char=? #\- (string-ref chrs (+ i 1))))
	     (let ((nxt (recur (+ i 3))))
	       (lambda (ch)
		 (or (and (ch<=? ch (string-ref chrs (+ i 2)))
			  (ch<=? (string-ref chrs i) ch))
		     (nxt ch)))))
	    (else
	     (let ((nxt (recur (+ i 1)))
		   (chrsi (string-ref chrs i)))
	       (lambda (ch)
		 (or (ch=? chrsi ch) (nxt ch))))))))
  (define (match-set tok nxt)
    (let ((chrs (substring tok 1 (- (string-length tok) 1))))
      (if (and (positive? (string-length chrs))
	       (memv (string-ref chrs 0) '(#\^ #\!)))
	  (let ((pred (match-set1 (substring chrs 1 (string-length chrs)))))
	    (lambda (str k kmatch)
	      (and (< k (string-length str))
		   (not (pred (string-ref str k)))
		   (nxt str (+ k 1) (cons k kmatch)))))
	  (let ((pred (match-set1 chrs)))
	    (lambda (str k kmatch)
	      (and (< k (string-length str))
		   (pred (string-ref str k))
		   (nxt str (+ k 1) (cons k kmatch))))))))
  (define (match-* nxt)
    (lambda (str k kmatch)
      (let ((kmatch (cons k kmatch)))
	(let loop ((kk (string-length str)))
	  (and (>= kk k)
	       (or (nxt str kk kmatch)
		   (loop (- kk 1))))))))
  
  (let ((matcher
	 (let recur ((toks (glob:pattern->tokens pat)))
	   (if (null? toks)
	       match-end
	       (let ((pch (or (string=? (car toks) "")
			      (string-ref (car toks) 0))))
		 (case pch
		   ((#\?) (match-? (recur (cdr toks))))
		   ((#\*) (match-* (recur (cdr toks))))
		   ((#\[) (match-set (car toks) (recur (cdr toks))))
		   (else (match-str (car toks) (recur (cdr toks))))))))))
    (lambda (str) (matcher str 0 '()))))


(define (filename:match?? pattern)
  (glob:make-matcher pattern char=? char<=?))



;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; "printf.scm" Implementation of standard C functions for Scheme


;; (define (stdio:iprintf out format-string . args)
;;   (cond
;;    ((not (equal? "" format-string))
;;     (let ((pos -1)
;; 	  (fl (string-length format-string))
;; 	  (fc (string-ref format-string 0)))

;;       (define (advance)
;; 	(set! pos (+ 1 pos))
;; 	(cond ((>= pos fl) (set! fc #f))
;; 	      (else (set! fc (string-ref format-string pos)))))
;;       (define (must-advance)
;; 	(set! pos (+ 1 pos))
;; 	(cond ((>= pos fl) (incomplete))
;; 	      (else (set! fc (string-ref format-string pos)))))
;;       (define (end-of-format?)
;; 	(>= pos fl))
;;       (define (incomplete)
;; 	(slib:error 'printf "conversion specification incomplete"
;; 		    format-string))
;;       (define (wna)
;; 	(slib:error 'printf "wrong number of arguments"
;; 		    (length args)
;; 		    format-string))
;;       (define (out* strs)
;; 	(if (string? strs) (out strs)
;; 	    (let out-loop ((strs strs))
;; 	      (or (null? strs)
;; 		  (and (out (car strs))
;; 		       (out-loop (cdr strs)))))))

;;       (let loop ((args args))
;; 	(advance)
;; 	(cond
;; 	 ((end-of-format?)
;; 	  ;;(or (null? args) (wna))	;Extra arguments are *not* a bug.
;; 	  )
;; 	 ((eqv? #\\ fc);;Emulating C strings may not be a good idea.
;; 	  (must-advance)
;; 	  (and (case fc
;; 		 ((#\n #\N) (out #\newline))
;; 		 ((#\t #\T) (out slib:tab))
;; 		 ;;((#\r #\R) (out #\return))
;; 		 ((#\f #\F) (out slib:form-feed))
;; 		 ((#\newline) #t)
;; 		 (else (out fc)))
;; 	       (loop args)))
;; 	 ((eqv? #\% fc)
;; 	  (must-advance)
;; 	  (let ((left-adjust #f)	;-
;; 		(signed #f)		;+
;; 		(blank #f)
;; 		(alternate-form #f)	;#
;; 		(leading-0s #f)		;0
;; 		(width 0)
;; 		(precision -1)
;; 		(type-modifier #f)
;; 		(read-format-number
;; 		 (lambda ()
;; 		   (cond
;; 		    ((eqv? #\* fc)	; GNU extension
;; 		     (must-advance)
;; 		     (let ((ans (car args)))
;; 		       (set! args (cdr args))
;; 		       ans))
;; 		    (else
;; 		     (do ((c fc fc)
;; 			  (accum 0 (+ (* accum 10)
;; 				      (string->number (string c)))))
;; 			 ((not (char-numeric? fc)) accum)
;; 		       (must-advance)))))))
;; 	    (define (pad pre . strs)
;; 	      (let loop ((len (string-length pre))
;; 			 (ss strs))
;; 		(cond ((>= len width) (cons pre strs))
;; 		      ((null? ss)
;; 		       (cond (left-adjust
;; 			      (cons pre
;; 				    (append strs
;; 					    (list (make-string
;; 						   (- width len) #\space)))))
;; 			     (leading-0s
;; 			      (cons pre
;; 				    (cons (make-string (- width len) #\0)
;; 					  strs)))
;; 			     (else
;; 			      (cons (make-string (- width len) #\space)
;; 				    (cons pre strs)))))
;; 		      (else
;; 		       (loop (+ len (string-length (car ss))) (cdr ss))))))
;; 	    (define integer-convert
;; 	      (lambda (s radix fixcase)
;; 		(cond ((not (negative? precision))
;; 		       (set! leading-0s #f)
;; 		       (if (and (zero? precision)
;; 				(eqv? 0 s))
;; 			   (set! s ""))))
;; 		(set! s (cond ((symbol? s) (symbol->string s))
;; 			      ((number? s) (number->string s radix))
;; 			      ((or (not s) (null? s)) "0")
;; 			      ((string? s) s)
;; 			      (else "1")))
;; 		(if fixcase (set! s (fixcase s)))
;; 		(let ((pre (cond ((equal? "" s) "")
;; 				 ((eqv? #\- (string-ref s 0))
;; 				  (set! s (substring s 1 (string-length s)))
;; 				  "-")
;; 				 (signed "+")
;; 				 (blank " ")
;; 				 (alternate-form
;; 				  (case radix
;; 				    ((8) "0")
;; 				    ((16) "0x")
;; 				    (else "")))
;; 				 (else ""))))
;; 		  (pad pre
;; 		       (if (< (string-length s) precision)
;; 			   (make-string
;; 			    (- precision (string-length s)) #\0)
;; 			   "")
;; 		       s))))
;; 	    (define (float-convert num fc)
;; 	      (define (f digs exp strip-0s)
;; 		(let ((digs (stdio:round-string
;; 			     digs (+ exp precision) (and strip-0s exp))))
;; 		  (cond ((>= exp 0)
;; 			 (let* ((i0 (cond ((zero? exp) 0)
;; 					  ((char=? #\0 (string-ref digs 0)) 1)
;; 					  (else 0)))
;; 				(i1 (max 1 (+ 1 exp)))
;; 				(idigs (substring digs i0 i1))
;; 				(fdigs (substring digs i1
;; 						  (string-length digs))))
;; 			   (cons idigs
;; 				 (if (and (string=? fdigs "")
;; 					  (not alternate-form))
;; 				     '()
;; 				     (list "." fdigs)))))
;; 			((zero? precision)
;; 			 (list (if alternate-form "0." "0")))
;; 			((and strip-0s (string=? digs "") (list "0")))
;; 			(else
;; 			 (list "0."
;; 			       (make-string (min precision (- -1 exp)) #\0)
;; 			       digs)))))
;; 	      (define (e digs exp strip-0s)
;; 		(let* ((digs (stdio:round-string
;; 			      digs (+ 1 precision) (and strip-0s 0)))
;; 		       (istrt (if (char=? #\0 (string-ref digs 0)) 1 0))
;; 		       (fdigs (substring
;; 			       digs (+ 1 istrt) (string-length digs)))
;; 		       (exp (if (zero? istrt) exp (- exp 1))))
;; 		  (list
;; 		   (substring digs istrt (+ 1 istrt))
;; 		   (if (and (string=? fdigs "") (not alternate-form))
;; 		       "" ".")
;; 		   fdigs
;; 		   (if (char-upper-case? fc) "E" "e")
;; 		   (if (negative? exp) "-" "+")
;; 		   (if (< -10 exp 10) "0" "")
;; 		   (number->string (abs exp)))))
;; 	      (define (g digs exp)
;; 		(let ((strip-0s (not alternate-form)))
;; 		  (set! alternate-form #f)
;; 		  (cond ((<= (- 1 precision) exp precision)
;; 			 (set! precision (- precision exp))
;; 			 (f digs exp strip-0s))
;; 			(else
;; 			 (set! precision (- precision 1))
;; 			 (e digs exp strip-0s)))))
;; 	      (define (k digs exp sep)
;; 		(let* ((units '#("y" "z" "a" "f" "p" "n" "u" "m" ""
;; 				 "k" "M" "G" "T" "P" "E" "Z" "Y"))
;; 		       (base 8)		;index of ""
;; 		       (uind (let ((i (if (negative? exp)
;; 					  (quotient (- exp 3) 3)
;; 					  (quotient (- exp 1) 3))))
;; 			       (and
;; 				(< -1 (+ i base) (vector-length units))
;; 				i))))
;; 		  (cond (uind
;; 			 (set! exp (- exp (* 3 uind)))
;; 			 (set! precision (max 0 (- precision exp)))
;; 			 (append
;; 			  (f digs exp #f)
;; 			  (list sep
;; 				(vector-ref units (+ uind base)))))
;; 			(else
;; 			 (g digs exp)))))

;; 	      (cond ((negative? precision)
;; 		     (set! precision 6))
;; 		    ((and (zero? precision)
;; 			  (char-ci=? fc #\g))
;; 		     (set! precision 1)))
;; 	      (let* ((str
;; 		      (cond ((number? num)
;; 			     (number->string (exact->inexact num)))
;; 			    ((string? num) num)
;; 			    ((symbol? num) (symbol->string num))
;; 			    (else "???"))))
;; 		(define (format-real signed? sgn digs exp . rest)
;; 		  (if (null? rest)
;; 		      (cons
;; 		       (if (char=? #\- sgn) "-"
;; 			   (if signed? "+" (if blank " " "")))
;; 		       (case fc
;; 			 ((#\e #\E) (e digs exp #f))
;; 			 ((#\f #\F) (f digs exp #f))
;; 			 ((#\g #\G) (g digs exp))
;; 			 ((#\k) (k digs exp ""))
;; 			 ((#\K) (k digs exp "."))))
;; 		      (append (format-real signed? sgn digs exp)
;; 			      (apply format-real #t rest)
;; 			      '("i"))))
;; 		(or (stdio:parse-float str
;; 				    (lambda (sgn digs expon . imag)
;; 				      (apply pad
;; 					     (apply format-real
;; 						    signed
;; 						    sgn digs expon imag))))
;; 		    (pad "???"))))
;; 	    (do ()
;; 		((case fc
;; 		   ((#\-) (set! left-adjust #t) #f)
;; 		   ((#\+) (set! signed #t) #f)
;; 		   ((#\space) (set! blank #t) #f)
;; 		   ((#\#) (set! alternate-form #t) #f)
;; 		   ((#\0) (set! leading-0s #t) #f)
;; 		   (else #t)))
;; 	      (must-advance))
;; 	    (cond (left-adjust (set! leading-0s #f)))
;; 	    (cond (signed (set! blank #f)))

;; 	    (set! width (read-format-number))
;; 	    (cond ((negative? width)
;; 		   (set! left-adjust #t)
;; 		   (set! width (- width))))
;; 	    (cond ((eqv? #\. fc)
;; 		   (must-advance)
;; 		   (set! precision (read-format-number))))
;; 	    (case fc			;Ignore these specifiers
;; 	      ((#\l #\L #\h)
;; 	       (set! type-modifier fc)
;; 	       (must-advance)))

;; 	    ;;At this point fc completely determines the format to use.
;; 	    (if (null? args)
;; 		(if (memv (char-downcase fc)
;; 			  '(#\c #\s #\a #\d #\i #\u #\o #\x #\b
;; 			    #\f #\e #\g #\k))
;; 		    (wna)))

;; 	    (case fc
;; 		;; only - is allowed between % and c
;; 	      ((#\c #\C)		; C is enhancement
;; 	       (and (out (string (car args))) (loop (cdr args))))

;; 	      ;; only - flag, no type-modifiers
;; 	      ((#\s #\S)		; S is enhancement
;; 	       (let ((s (cond
;; 			 ((symbol? (car args)) (symbol->string (car args)))
;; 			 ((not (car args)) "(NULL)")
;; 			 (else (car args)))))
;; 		 (cond ((not (or (negative? precision)
;; 				 (>= precision (string-length s))))
;; 			(set! s (substring s 0 precision))))
;; 		 (and
;; 		  (out* (cond
;; 			 ((<= width (string-length s)) s)
;; 			 (left-adjust
;; 			  (list
;; 			   s (make-string (- width (string-length s)) #\space)))
;; 			 (else
;; 			  (list
;; 			   (make-string (- width (string-length s))
;; 					(if leading-0s #\0 #\space))
;; 			   s))))
;; 		  (loop (cdr args)))))

;; 		;; SLIB extension
;; 	      ((#\a #\A)		;#\a #\A are pretty-print
;; 	       (let ((os "") (pr precision))
;; 		 (require 'generic-write)
;; 		 (generic-write
;; 		  (car args) (not alternate-form) #f
;; 		  (cond ((and left-adjust (negative? pr))
;; 			 (set! pr 0)
;; 			 (lambda (s)
;; 			   (set! pr (+ pr (string-length s)))
;; 			   (out s)))
;; 			(left-adjust
;; 			 (lambda (s)
;; 			   (define sl (- pr (string-length s)))
;; 			   (set! pr (cond ((negative? sl)
;; 					   (out (substring s 0 pr)) 0)
;; 					  (else (out s) sl)))
;; 			   (positive? sl)))
;; 			((negative? pr)
;; 			 (set! pr width)
;; 			 (lambda (s)
;; 			   (set! pr (- pr (string-length s)))
;; 			   (cond ((not os) (out s))
;; 				 ((negative? pr)
;; 				  (out os)
;; 				  (set! os #f)
;; 				  (out s))
;; 				 (else (set! os (string-append os s))))
;; 			   #t))
;; 			(else
;; 			 (lambda (s)
;; 			   (define sl (- pr (string-length s)))
;; 			   (cond ((negative? sl)
;; 				  (set! os (string-append
;; 					    os (substring s 0 pr))))
;; 				 (else (set! os (string-append os s))))
;; 			   (set! pr sl)
;; 			   (positive? sl)))))
;; 		 (cond ((and left-adjust (negative? precision))
;; 			(cond
;; 			 ((> width pr) (out (make-string (- width pr) #\space)))))
;; 		       (left-adjust
;; 			(cond
;; 			 ((> width (- precision pr))
;; 			  (out (make-string (- width (- precision pr)) #\space)))))
;; 		       ((not os))
;; 		       ((<= width (string-length os)) (out os))
;; 		       (else (and (out (make-string
;; 					(- width (string-length os)) #\space))
;; 				  (out os)))))
;; 	       (loop (cdr args)))
;; 	      ((#\d #\D #\i #\I #\u #\U)
;; 	       (and (out* (integer-convert (car args) 10 #f))
;; 		    (loop (cdr args))))
;; 	      ((#\o #\O)
;; 	       (and (out* (integer-convert (car args) 8 #f))
;; 		    (loop (cdr args))))
;; 	      ((#\x)
;; 	       (and (out* (integer-convert
;; 			   (car args) 16
;; 			   (if stdio:hex-upper-case? string-downcase #f)))
;; 		    (loop (cdr args))))
;; 	       ((#\X)
;; 	       (and (out* (integer-convert
;; 			   (car args) 16
;; 			   (if stdio:hex-upper-case? #f string-upcase)))
;; 		    (loop (cdr args))))
;; 	      ((#\b #\B)
;; 	       (and (out* (integer-convert (car args) 2 #f))
;; 		    (loop (cdr args))))
;; 	      ((#\%) (and (out #\%) (loop args)))
;; 	      ((#\f #\F #\e #\E #\g #\G #\k #\K)
;; 	       (and (out* (float-convert (car args) fc)) (loop (cdr args))))
;; 	      (else
;; 	       (cond
;; 		((end-of-format?) (incomplete))
;; 		(else (and (out #\%) (out fc) (out #\?) (loop args))))))))
;; 	 (else (and (out fc) (loop args)))))))))
;; ;@


;; ;@
;; (define (sprintf str format . args)
;;   (let* ((cnt 0)
;; 	 (s (cond ((string? str) str)
;; 		  ((number? str) (make-string str))
;; 		  ((not str) (make-string 100))
;; 		  (else (slib:error 'sprintf "first argument not understood"
;; 				    str))))
;; 	 (end (string-length s)))
;;     (apply stdio:iprintf
;; 	   (lambda (x)
;; 	     (cond ((string? x)
;; 		    (if (or str (>= (- end cnt) (string-length x)))
;; 			(do ((lend (min (string-length x) (- end cnt)))
;; 			     (i 0 (+ i 1)))
;; 			    ((>= i lend))
;; 			  (string-set! s cnt (string-ref x i))
;; 			  (set! cnt (+ cnt 1)))
;; 			(let ()
;; 			  (set! s (string-append (substring s 0 cnt) x))
;; 			  (set! cnt (string-length s))
;; 			  (set! end cnt))))
;; 		   ((and str (>= cnt end)))
;; 		   (else (cond ((and (not str) (>= cnt end))
;; 				(set! s (string-append s (make-string 100)))
;; 				(set! end (string-length s))))
;; 			 (string-set! s cnt (if (char? x) x #\?))
;; 			 (set! cnt (+ cnt 1))))
;; 	     (not (and str (>= cnt end))))
;; 	   format
;; 	   args)
;;     (cond ((string? str) cnt)
;; 	  ((eqv? end cnt) s)
;; 	  (else (substring s 0 cnt)))))

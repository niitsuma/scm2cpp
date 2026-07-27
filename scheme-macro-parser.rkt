#lang racket


(require macro-debugger/stepper)
(require macro-debugger/expand)

(require mzlib/defmacro)
(require  mzlib/compat)
(require mzlib/string)

(require racket/system)

(provide 
 s-read-div-define
 s-read-file-div-define
 s-readed-div-define-to-expand-code-str
 scheme-code-string-macro-expand
)


(define additional-expand-macro-symbols '(quasiquote))

;; (define (extract-define-name sexp)
;;   (let ((s1 (car sexp)))
;;     (if (atom? s1) s1 (caadr))))
       


(define (s-read-div-define )
  (let loop ( (macro-define-sexp-list '()) (define-sexp-list '()) (other-sexp-list '()) (s (read)) )
          (if (eof-object? s)
              (list (reverse macro-define-sexp-list)  (reverse define-sexp-list)(reverse other-sexp-list))
              (let ((s1 (car s)))
                ;;(display (extract-define-name s))
                (cond
                  ((or (eq? s1 'define-macro) (eq? s1 'defmacro) (eq? s1 'syntax-rules ) (eq? s1 'syntax-case ) (eq? s1 'define-syntax  ))
                   (if (atom? (cadr s))
                       (loop (cons (cons (cadr s)  s) macro-define-sexp-list) define-sexp-list other-sexp-list (read))
                       (loop (cons (cons (caadr s)  s) macro-define-sexp-list) define-sexp-list other-sexp-list (read))
                       ))
                  ;((eq? s1 'define)
                  ; (loop macro-define-sexp-list (cons s define-sexp-list) other-sexp-list (read)))
                  (else 
                   (loop macro-define-sexp-list define-sexp-list (cons s other-sexp-list) (read))
                   ))))))

(define (s-readed-div-define-result-recompose-list slst)
  (let ((macro-name-list (map car  (car slst)) ))
 (append
  (list '('require 'mzlib/defmacro))
  (list (cons 'provide  macro-name-list))
  (map cdr  (car slst))
  (cadr slst)
  (caddr slst))))
  
(define (s-readed-div-define-to-expand-code-str slst)
  ;(display slst)
  (let* ((macro-name-symbol-list 
	  (append (map car  (car slst)) additional-expand-macro-symbols )
	  )
         (macro-name-qlist-str (apply string-append (map (lambda (x) (string-append "#'" (symbol->string x) " ")) macro-name-symbol-list)))
         (macro-name-list-str (apply string-append (map (lambda (x) (string-append " " (symbol->string x) " ")) macro-name-symbol-list)))
         )
    
    ;(display macro-name-symbol-list)
    (display "#lang scheme")
    (display 
"
(require mzlib/defmacro)
(require macro-debugger/stepper)
(require macro-debugger/expand)") (newline)
    (map 
     (lambda (s) (write (cdr s)) (newline))
     (car slst))
    (display  (format "(provide ~a)" macro-name-list-str)) (newline)
    (map 
     (lambda (s)
       (display "(write (syntax->datum (expand-only #'" ) (write s) (display (format "(list ~a))))(newline)"  macro-name-qlist-str))(newline))
     (cadr slst)
     )
    (map 
     (lambda (s)
       (display "(write (syntax->datum (expand-only #'" ) (write s) (display (format "(list ~a))))(newline)"  macro-name-qlist-str))(newline))
     (caddr slst)
     )
    ))
  

  
(define (s-read-file-div-define file-name)
  (with-input-from-file file-name s-read-div-define))
  

(define (scheme-code-string-macro-expand scmcode)
  (let ((sread-ret (with-input-from-string scmcode s-read-div-define)))    
    (if (null? (car sread-ret))
       scmcode
       (begin 
         (with-output-to-file "/tmp/code-expanded.scm" 
           (lambda () 
             (s-readed-div-define-to-expand-code-str sread-ret)
             ) #:exists 'replace )
         (port->string (car (process    (format  "racket /tmp/code-expanded.scm")))) ))
    ))

;;;;;;;;;debug

;(define sread-ret (s-read-file-div-define "comp-test.scm"))
;(with-output-to-file "/tmp/code-expanded.scm" (lambda () (s-readed-div-define-to-expand-code-str sread-ret))   	#:exists 'replace )
;(display (port->string (car (process    (format  "racket /tmp/code-expanded.scm")))) )




;(display (car sread-ret ))
;(newline)
;(write (cadr sread-ret ))
;(newline)
;(display (caddr sread-ret ))
;(newline)(newline)


;(with-input-from-string scmcode2 s-read-div-define)



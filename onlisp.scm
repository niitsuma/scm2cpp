#lang racket

;;; The utilities in this file (aif, awhen, awhile, acond, alambda, map0-n,
;;; mapa-b, symb, group, flatten, ... ) follow those published in
;;;   Paul Graham, "On Lisp", Prentice Hall, 1993.
;;; The book's code is made freely available by the author at
;;;   http://www.paulgraham.com/onlisp.html
;;; This file is a Scheme/Racket rendering of those utilities.
;;;
;;; Rendering and modifications: Copyright (C) 2011-2026 Hirotaka Niitsuma

(provide
 funcall
 ;lrec
 atom?  not-null?
 ;ttrav
 ;trac
 ;while
 ;dolist
 map0-n
 map1-n
 nthcdr
 aif awhen awhile aand acond alambda 
 ;ablock
 ;aif2 
 awhen2 awhile2 acond2
 ;memoize

 abbrev 
 ;abbrevs
)


(require srfi/1)
;(require srfi/17)
;(require mzscheme)
(require mzlib/defmacro)
(require "list-util.scm")

(require "cl-util.scm")

;; (define-module onlisp
;;   (use srfi-1)
;;   (use srfi-17)
;;   (use gauche.array)
;;   (use gauche.sequence)
;;   (use util.list)
;;   (use util.match)
;;   (extend simple-draw)
;;   (export atom? gensym
;;           complement compose memoize
;;           fif fint fun
;;           funcall lrec ttrav trec
;;           nil! when while dolist when-bind block
;;           sum1 sum avg with-redraw
;;           bad-for for echo
;;           nth orb our-let when-bind* with-gensyms
;;           in inq in-if >case >casex
;;           forever till do-tuples/o do-tuples/c
;;           mvdo* mvdo mvpsetq setq allf mklist
;;           symbol-value get-setf-method _! pull pull-if popn
;;           rotatef sortf
;;           most-of nthmost gen-start nthmost-gen genbez
;;           aif awhen awhile aand acond alambda ablock
;;           aif2 awhen2 awhile2 acond2
;;           fn rbuild build-call build-compose
;;           alrec on-cdrs atrec on-trees
;;           delay force *unforced* delay?
;;           abbrev abbrevs propmacro propmacros get
;;           a+ a+expand  alist alist-expand
;;           defanaph anaphex pop-symbol
;;           def-anaph anaphex1 anaphex2 anaphex3
;;           dbind destruc dbind-ex with-matrix with-array
;;           receive* receive
;;           match-fn if-match-ls if-match pat-match 
;;           )
;;   )

;; (select-module onlisp)

;; (define (complement pred)
;;   (lambda args (not (apply pred args))))

;; (define (compose . fns)
;;   (if (null? fns)
;;       identity
;;       (let ((fn1 (car (reverse fns)))
;;             (fns (reverse (cdr (reverse fns)))))
;;         (lambda args ((apply compose fns) (apply fn1 args))))))

;; (define (memoize fn)
;;   (let ((cache (make-hash-table 'equal?)))
;;     (lambda args
;;       (if (hash-table-exists? cache args)
;;           (hash-table-get cache args)
;;           (let ((val (apply fn args)))
;;             (hash-table-put! cache args val)
;;             val)))))

;; (define (fif pred then . alt)
;;   (lambda args
;;     (if (apply pred args)
;;         (apply then args)
;;         (if (null? alt)
;;             #f
;;             (apply (car alt) args)))))

;; (define (fint fn . fns)
;;   (if (null? fns)
;;       fn
;;       (lambda args
;;         (and (apply fn args)
;;              (apply (apply fint fns) args)))))

;; (define (fun fn . fns)
;;   (if (null? fns)
;;       fn
;;       (lambda args
;;         (or (apply fn args)
;;             (apply (apply fun fns) args)))))

(define (funcall fn . args)
  (apply fn args))

;; (define (lrec rec . base)
;;   (letrec ((self (lambda (lst)
;;                    (if (null? lst)
;;                        (let ((base (get-optional base '())))
;;                          (if (procedure? base)
;;                              (base)
;;                              base))
;;                        (rec (car lst)
;;                             (lambda ()
;;                               (self (cdr lst))))))))
;;     self))

(define (lrec rec . base)
  (letrec ((self (lambda (lst)
		   ;(print (list lst base))
                   (if (null? lst)
                       ;(let ((base (get-optional base '())))
                         (if (procedure? base)
                             (base)
                             base)
			 ;)
                       (rec (car lst)
                            (lambda ()
                              (self (cdr lst))))))))
    self))


;; ( (lrec (lambda (x f) (+ 1 (funcall f))) 0)
;;   '(1 2 (3 4 (5) 6) 7 (8 9)))
;; ( (lrec (lambda (x f) (+ 1 (funcall f))) 0)
;;   '(1))



(define atom? (compose not pair?))
(define not-null? (compose not null?))

;; (define (ttrav rec . base)
;;   (let ((base (get-optional base identity)))
;;     (letrec ((self (lambda (tree)
;;                      (if (atom? tree)
;;                          (if (procedure? base)
;;                              (base tree)
;;                              base)
;;                          (rec (self (car tree))
;;                               (if (not-null? (cdr tree))
;;                                   (self (cdr tree)) '()))))))
;;       self)))

;; (define (trec rec . base)
;;   (let ((base (get-optional base identity)))
;;     (letrec ((self (lambda (tree)
;;                      (if (atom? tree)
;;                          (if (procedure? base)
;;                              (base tree)
;;                              base)
;;                          (rec tree
;;                               (lambda ()
;;                                 (self (car tree)))
;;                               (lambda ()
;;                                 (self (cdr tree))))))))
;;       self)))

;; (define-macro (nil! var) `(set! ,var #f))

;; (define-macro (when test . body)
;;   `(if ,test (begin ,@body)))

;; (define-macro (while test . body)
;;   `(do ()
;;        ((not ,test))
;;      ,@body))

;; (define-macro (dolist var-lst-res . body)
;;   (match var-lst-res
;;          ((var lst . res)
;;           `(begin
;;              (map (lambda (,var) ,@body)
;;                   ,lst)
;;              (let ((,var '()))
;;                ,@res)))))

;; (define-macro (when-bind var-expr . body)
;;   (match var-expr
;;          ((var expr)
;;           `(let ((,var ,expr))
;;              (when ,var ,@body)))))

;; (define-macro (block tag . body)
;;   `(call/cc (lambda (,tag) ,@body)))

;; (define-macro (sum1 . args)
;;   `(apply + (list ,@args)))

;; (define-macro (sum . args)
;;   `(+ ,@args))

;; (define-macro (avg . args)
;;   `(/ (+ ,@args) ,(length args)))

;; (define-macro (with-redraw var-objs . body)
;;   (match var-objs
;;          ((var objs)
;;           (let ((gob (gensym))
;;                 (x0 (gensym)) (y0 (gensym))
;;                 (x1 (gensym)) (y1 (gensym)))
;;             `(let ((,gob ,objs))
;;                (receive (,x0 ,y0 ,x1 ,y1) (bounds ,gob)
;;                  (dolist (,var ,gob) ,@body)
;;                  (receive (xa ya xb yb) (bounds ,gob)
;;                    (redraw (min ,x0 xa) (min ,y0 ya)
;;                            (max ,x1 xb) (max ,y1 yb)))))))))

;; (define-macro (bad-for var-start-stop . body)
;;   (match var-start-stop
;;          ((var start stop)
;;           `(do ((,var ,start (+ ,var 1))
;;                 (limit ,stop))
;;                ((> ,var limit))
;;              ,@body))))

;; (define-macro (for var-start-stop . body)
;;   (match var-start-stop
;;          ((var start stop)
;;           (let ((limit (gensym)))
;;             `(do ((,var ,start (+ ,var 1))
;;                   (,limit ,stop))
;;                  ((> ,var ,limit))
;;                ,@body)))))

;; (define-macro (echo . args)
;;   `'(,@args amem))

;; (define-macro (nth n lst)
;;   `(letrec ((nth-fn (lambda (n lst)
;;                       (if (= n 0)
;;                           (car lst)
;;                           (nth-fn (- n 1) (cdr lst))))))
;;      (nth-fn ,n ,lst)))

;; (define-macro (orb . args)
;;   (if (null? args)
;;       #f
;;       (let ((sym (gensym)))
;;         `(let ((,sym ,(car args)))
;;            (if ,sym
;;                ,sym
;;                (orb ,@(cdr args)))))))

;; (define-macro (our-let binds . body)
;;   `((lambda ,(map (lambda (x)
;;                     (if (pair? x) (car x) x))
;;                   binds)
;;       ,@body)
;;     ,@(map (lambda (x)
;;              (if (pair? x) (cadr x) #f))
;;            binds)))

;; (define-macro (when-bind* binds . body)
;;   (if (null? binds)
;;       `(begin ,@body)
;;       `(let (,(car binds))
;;          (if ,(caar binds)
;;              (when-bind* ,(cdr binds) ,@body)))))

;; (define-macro (with-gensyms syms . body)
;;   `(let ,(map (lambda (s)
;;                 `(,s (gensym)))
;;               syms)
;;      ,@body))

;; (define-macro (in obj . choices)
;;   (let ((insym (gensym)))
;;     `(let ((,insym ,obj))
;;        (or ,@(map (lambda (c) `(equal? ,insym ,c))
;;                   choices)))))

;; (define-macro (inq obj . args)
;;   `(in ,obj ,@(map (lambda (a) `',a)
;;                    args)))

;; (define-macro (in-if fn . choices)
;;   (let ((fnsym (gensym)))
;;     `(let ((,fnsym ,fn))
;;        (or ,@(map (lambda (c) `(,fnsym ,c))
;;                   choices)))))

;; (define-macro (>case expr . clauses)
;;   (let ((g (gensym)))
;;     `(let ((,g ,expr))
;;        (cond ,@(map (lambda (cl) (>casex g cl))
;;                     clauses)))))

;; (define (>casex g cl)
;;   (let ((key (car cl)) (rest (cdr cl)))
;;     (cond ((pair? key) `((in ,g ,@key) ,@rest))
;;           ((inq key #t otherwise) `(#t ,@rest))
;;           (else (error "bad >case clause")))))

;; (define-macro (forever . body)
;;   `(do () (#f) ,@body))

;; (define-macro (till test . body)
;;   `(do ()
;;        (,test)
;;      ,@body))

(define (map0-n fn len)
  (map fn (iota (+ len 1))))

(define (map1-n fn len)
  (map fn (iota len 1)))

(define (nthcdr n lst)
  (if (null? lst)
      '()
      (if (<= n 0)
          lst
          (nthcdr (- n 1) (cdr lst)))))

(define (rmapcar fn . args)
  (if (cl:some atom? args)
      (apply fn args)
      (apply
       map
       `(,(lambda args
	    ;(print args)
	    (apply rmapcar `(,fn . ,args))) 
            . ,args))))


;; > (rmapcar print '(1 2 (3 4 (5) 6) 7 (8 9)))
;; 123456789
;; (1 2 (3 4 (5) 6) 7 (8 9))
;; > (rmapcar + '(1 (2 (3) 4)) '(10 (20 (30) 40)))
;; (11 (22 (33) 44))
;; (rmapcar + 1 10)
;; (rmapcar + '(1) '(10))


;; (define-macro (do-tuples/o parms source . body)
;;   (if (not-null? parms)
;;       (let ((src (gensym)))
;;         `(let ((,src ,source))
;;            (for-each (lambda ,parms ,@body)
;;                      ,@(map0-n (lambda (n)
;;                                  `(,nthcdr ,n ,src))
;;                                (- (length parms) 1)))))))

;; (define-macro (do-tuples/c parms source . body)
;;   (if (not-null? parms)
;;       (with-gensyms (src rest bodfn)
;;                     (let ((len (length parms)))
;;                       `(let ((,src ,source))
;;                          (when (,not-null? (,nthcdr ,(- len 1) ,src))
;;                            (letrec ((,bodfn (lambda ,parms ,@body)))
;;                              (do ((,rest ,src (cdr ,rest)))
;;                                  ((null? (,nthcdr ,(- len 1) ,rest))
;;                                   ,@(map (lambda (args)
;;                                            `(,bodfn ,@args))
;;                                          (dt-args len rest src))
;;                                   #f)
;;                                (,bodfn ,@(map1-n (lambda (n)
;;                                                    `(nth ,(- n 1)
;;                                                          ,rest))
;;                                                  len))))))))))

;; (define (dt-args len rest src)
;;   (map0-n (lambda (m)
;;             (map1-n (lambda (n)
;;                       (let ((x (+ m n)))
;;                         (if (>= x len)
;;                             `(nth ,(- x len) ,src)
;;                             `(nth ,(- x 1) ,rest))))
;;                     len))
;;           (- len 2)))

;; (define-macro (mvdo* parm-cl test-cl . body)
;;   (mvdo-gen parm-cl parm-cl test-cl body))

;; (define (mvdo-gen binds rebinds test body)
;;   (if (null? binds)
;;       (let ((label (gensym))
;;             (return (gensym)))
;;         `(block ,return
;;                 (let ,label ()
;;                      (if ,(car test)
;;                          (,return (begin ,@(cdr test))))
;;                      ,@body
;;                      ,@(mvdo-rebind-gen rebinds)
;;                      (,label))))
;;       (let ((rec (mvdo-gen (cdr binds) rebinds test body)))
;;         (let ((var/s (caar binds)) (expr (cadar binds)))
;;           (if (not (pair? var/s))
;;               `(let ((,var/s ,expr)) ,rec)
;;               `(receive ,var/s ,expr ,rec))))))

;; (define (mvdo-rebind-gen rebinds)
;;   (cond ((null? rebinds) '())
;;         ((< (length (car rebinds)) 3)
;;          (mvdo-rebind-gen (cdr rebinds)))
;;         (else (cons (list (if (not (pair? (caar rebinds)))
;;                               'set!
;;                               'set!-values)
;;                           (caar rebinds)
;;                           (list-ref (car rebinds) 2))
;;                     (mvdo-rebind-gen (cdr rebinds))))))

;; (define (mklist obj)
;;   (if (list? obj) obj (list obj)))

;; (define (group source n)
;;   (if (zero? n) (error "zero lenght"))
;;   (letrec ((rec (lambda (source acc)
;;                   (let ((rest (drop* source n)))
;;                     (if (pair? rest)
;;                         (rec rest (cons (take source n) acc))
;;                         (reverse (cons source acc)))))))
;;     (if (null? source) '() (rec source '()))))

;; (define (shuffle x y)
;;   (cond ((null? x) y)
;;         ((null? y) x)
;;         (else (list* (car x) (car y)
;;                      (shuffle (cdr x) (cdr y))))))

;; (define-macro (setq . args)
;;   (if (null? args)
;;       '()
;;       (let ((pairs (group args 2)))
;;         `(begin
;;            ,@(map (lambda (p)
;;                     `(guard (e (#t (eval `(define ,',(car p) ',,(cadr p))
;;                                          (current-module))))
;;                             (set! ,@p)))
;;                   pairs)))))

;; (define-macro (mvpsetq . args)
;;   (let* ((pairs (group args 2))
;;          (syms (map (lambda (p)
;;                       (map (lambda _ (gensym))
;;                            (mklist (car p))))
;;                     pairs)))
;;     (letrec ((rec (lambda (ps ss)
;;                     (if (null? ps)
;;                         `(setq   ;; could be hidden as ,setq
;;                           ,@(append-map (lambda (p s)
;;                                           (shuffle (mklist (car p))
;;                                                    s))
;;                                         pairs syms))
;;                         (let ((body (rec (cdr ps) (cdr ss))))
;;                           (let ((var/s (caar ps))
;;                                 (expr (cadar ps)))
;;                             (if (pair? var/s)
;;                                 `(receive ,(car ss)
;;                                      ,expr
;;                                    ,body)
;;                                 `(let ((,@(car ss) ,expr))
;;                                    ,body))))))))
;;       (rec pairs syms))))

;; (define-macro (mvdo binds test-result . body)
;;   (match test-result
;;          ((test . result)
;;           (let ((label (gensym))
;;                 (return (gensym))
;;                 (temps (map (lambda (b)
;;                               (if (pair? (car b))
;;                                   (map (lambda (x)
;;                                          (gensym))
;;                                        (car b))
;;                                   (gensym)))
;;                             binds)))
;;             `(let ,(map list
;;                         (append-map mklist temps)
;;                         (make-list (length (append-map mklist temps)) #f))
;;                (mvpsetq ,@(append-map (lambda (b var)
;;                                         (list var (cadr b)))
;;                                       binds
;;                                       temps))
;;                (block ,return
;;                       (let ,(map (lambda (b var) (list b var))
;;                                  (append-map mklist (map car binds))
;;                                  (append-map mklist temps))
;;                         (let ,label ()
;;                              (if ,test
;;                                  (,return (begin ,@result)))
;;                              ,@body
;;                              (mvpsetq ,@(append-map (lambda (b)
;;                                                       (if (caddr b)
;;                                                           (list (car b)
;;                                                                 (caddr b))))
;;                                                     binds))
;;                              (,label)))))))))

;; (define-macro (allf val . args)
;;   (with-gensyms (gval)
;;                 `(let ((,gval ,val))
;;                    (setq ,@(append-map (lambda (a) (list a gval))
;;                                        args)))))

;; (define-macro (symbol-value sym)
;;   `(eval ,sym (current-module)))

;; (define (make-gensym n)
;;   (if (= n 0) '() (cons (gensym) (make-gensym (- n 1)))))

;; (define (get-setf-method place)
;;   (cond ((symbol? place)
;;          (let ((g (gensym)))
;;            (values '() '() (list g) `(set! ,place ,g) place)))
;;         ((pair? place)
;;          (let* ((forms (cdr place))
;;                 (vars (make-gensym (length forms)))
;;                 (var (list (gensym)))
;;                 (set `((setter ,(car place)) ,@vars ,@var))
;;                 (access (cons (car place) vars)))
;;            (values vars forms var set access)))))

;; (define-macro (_! op place . args)
;;   (receive (vars forms var set access)
;;       (get-setf-method place)
;;     `(let* (,@(map list vars forms)
;;             (,(car var) (,op ,access ,@args)))
;;        ,set)))

;; (define-macro (pull obj place . args)
;;   (receive (vars forms var set access)
;;       (get-setf-method place)
;;     (let ((g (gensym)))
;;       `(let* ((,g ,obj)
;;               ,@(map list vars forms)
;;               (,(car var) (,delete ,g ,access ,@args)))
;;          ,set))))

;; (define-macro (pull-if test place)
;;   (receive (vars forms var set access)
;;       (get-setf-method place)
;;     (let ((g (gensym)))
;;       `(let* ((,g ,test)
;;               ,@(map list vars forms)
;;               (,(car var) (,remove ,g ,access)))
;;          ,set))))

;; (define-macro (popn n place)
;;   (receive (vars forms var set access)
;;       (get-setf-method place)
;;     (with-gensyms (gn glst)
;;                   `(let* ((,gn ,n)
;;                           ,@(map list vars forms)
;;                           (,glst ,access)
;;                           (,(car var) (,nthcdr ,gn ,glst)))
;;                      (begin0 (,subseq ,glst ,gn)
;;                              ,set)))))

;; (define-macro (rotatef . args)
;;   (let* ((meths (map (lambda (p)
;;                        (call-with-values
;;                            (lambda _ (get-setf-method p)) list))
;;                      args))
;;          (temps (apply append (map third meths))))
;;     `(let* ,(map list
;;                  (append-map (lambda (m)
;;                                (append (first m)
;;                                        (third m)))
;;                              meths)
;;                  (append-map (lambda (m)
;;                                (append (second m)
;;                                        (list (fifth m))))
;;                              meths))
;;        ;; rotate logic...
;;        (mvpsetq ,@(append-map list temps (cdr temps))
;;                 ,(last temps) ,(car temps))
;;        ;; for set! effect.
;;        ,@(map fourth meths))))

;; (define-macro (sortf op . places)
;;   ;; for mapcon emu...
;;   (define (make-cdr-list lst)
;;     (if (null? (cdr lst))
;;         (list lst)
;;         (cons lst (make-cdr-list (cdr lst)))))
;;   (let* ((meths (map (lambda (p)
;;                        (call-with-values
;;                            (lambda _ (get-setf-method p)) list))
;;                      places))
;;          (temps (apply append (map third meths))))
;;     `(let* ,(map list
;;                  (append-map (lambda (m)
;;                                (append (first m)
;;                                        (third m)))
;;                              meths)
;;                  (append-map (lambda (m)
;;                                (append (second m)
;;                                        (list (fifth m))))
;;                              meths))
;;        ;; low level logic of sorting...
;;        ,@(append-map (lambda (rest)
;;                        (map (lambda (arg)
;;                               `(unless (,op ,(car rest) ,arg)
;;                                  (rotatef ,(car rest) ,arg)))
;;                             (cdr rest)))
;;                      (make-cdr-list temps))
;;        ;; for set! effect.
;;        ,@(map fourth meths))))

;; (define-macro (most-of . args)
;;   (let ((need (floor (/ (length args) 2)))
;;         (hits (gensym)))
;;     `(let ((,hits 0))
;;        (or ,@(map (lambda (a)
;;                     `(and ,a (> (inc! ,hits) ,need)))
;;                   args)))))

;; (define-macro (nthmost n lst)
;;   (if (and (integer? n) (< n 20))
;;       (with-gensyms (glst gi)
;;                     (let ((syms (map0-n (lambda (x) (gensym)) n)))
;;                       `(let ((,glst ,lst))
;;                          (unless (< (length ,glst) ,(+ 1 n))
;;                            ,@(gen-start glst syms)
;;                            (dolist (,gi ,glst)
;;                              ,(nthmost-gen gi syms #t))
;;                            ,(last syms)))))
;;       `(nth ,n (sort (list-copy ,lst) >))))

;; (define (gen-start glst syms)
;;   (define (make-cdr-list lst)
;;     (if (null? (cdr lst))
;;         (list lst)
;;         (cons lst (make-cdr-list (cdr lst)))))
;;   (reverse
;;    (map (lambda (syms)
;;           (let ((var (gensym)))
;;             `(let ((,var (pop! ,glst)))
;;                ,(nthmost-gen var (reverse syms)))))
;;         (make-cdr-list (reverse syms)))))

;; (define (nthmost-gen var vars . long?)
;;   (if (null? vars)
;;       '()
;;       (let ((long? (get-optional long? #f)))
;;         (let ((else (nthmost-gen var (cdr vars) long?)))
;;           (if (and (not long?) (null? else))
;;               `(setq ,(car vars) ,var)
;;               `(if (> ,var ,(car vars))
;;                    (setq ,@(append-map list
;;                                        (reverse vars)
;;                                        (cdr (reverse vars)))
;;                          ,(car vars) ,var)
;;                    ,else))))))

;; (define *segs* 20)
;; (define *du* (/ 1.0 *segs*))
;; (define *pts* (make-array (shape 0 *segs* 0 2)))
;; ((setter setter) array-ref array-set!)

;; (define-macro (genbez x0 y0 x1 y1 x2 y2 x3 y3)
;;   (with-gensyms (gx0 gx1 gy0 gy1 gx3 gy3)
;;                 `(let ((,gx0 ,x0) (,gy0 ,y0)
;;                        (,gx1 ,x1) (,gy1 ,y1)
;;                        (,gx3 ,x3) (,gy3 ,y3))
;;                    (let ((cx (* (- ,gx1 ,gx0) 3))
;;                          (cy (* (- ,gy1 ,gy0) 3))
;;                          (px (* (- ,x2 ,gx1) 3))
;;                          (py (* (- ,y2 ,gy1) 3)))
;;                      (let ((bx (- px cx))
;;                            (by (- py cy))
;;                            (ax (- ,gx3 px ,gx0))
;;                            (ay (- ,gy3 py ,gy0)))
;;                        (set! (,array-ref ,*pts* 0 0) ,gx0)
;;                        (set! (,array-ref ,*pts* 0 1) ,gy0)
;;                        ,@(map1-n (lambda (n)
;;                                    (let* ((u (* n *du*))
;;                                           (u^2 (* u u))
;;                                           (u^3 (expt u 3)))
;;                                      `(begin
;;                                         (set! (,array-ref ,*pts* ,n 0)
;;                                               (+ (* ax ,u^3)
;;                                                  (* bx ,u^2)
;;                                                  (* cx ,u)
;;                                                  ,gx0))
;;                                         (set! (,array-ref ,*pts* ,n 1)
;;                                               (+ (* ay ,u^3)
;;                                                  (* by ,u^2)
;;                                                  (* cy ,u)
;;                                                  ,gy0)))))
;;                                  (- *segs* 1))
;;                        (set! (,array-ref ,*pts* ,(- *segs* 1) 0) ,gx3)
;;                        (set! (,array-ref ,*pts* ,(- *segs* 1) 1) ,gy3))))))

(define-macro (aif test-form then-form . else-form)
  `(let ((it ,test-form))
     (if it ,then-form ,@else-form)))

;(aif (> 3 1) it 2)


(define-macro (awhen test-form . body)
  `(aif ,test-form
        (begin ,@body)))

(define-macro (awhile expr . body)
  `(do ((it ,expr ,expr))
       ((not it))
     ,@body))

(define-macro (aand . args)
  (cond ((null? args) #t)
        ((null? (cdr args)) (car args))
        (else `(aif ,(car args) (aand ,@(cdr args))))))

;;;; not work
;(aand 1 3)

(define-macro (acond . clauses)
  (if (null? clauses)
      '()
      (let ((cl1 (car clauses))
            (sym (gensym)))
        `(let ((,sym ,(car cl1)))
           (if ,sym
               (let ((it ,sym)) ,@(cdr cl1))
               (acond ,@(cdr clauses)))))))

(define-macro (alambda parms . body)
  `(letrec ((self (lambda ,parms ,@body)))
     self))

;; (define-macro (ablock tag . args)
;;   `(block ,tag
;;           ,((alambda (args)
;;                      (case (length args)
;;                        ((0) '())
;;                        ((1) (car args))
;;                        (else `(let ((it ,(car args)))
;;                                 ,(self (cdr args))))))
;;             args)))

;; (define-macro (aif2 test . then-else)
;;   (match then-else
;;          ((then . else)
;;           (let ((win (gensym)))
;;             `(receive (it ,win) ,test
;;                (if (or it ,win) ,then ,@else))))))

(define-macro (awhen2 test . body)
  `(aif2 ,test
         (begin ,@body)))
          
(define-macro (awhile2 test . body)
  (let ((flag (gensym)))
    `(let ((,flag #t))
       (while ,flag
         (aif2 ,test
               (begin ,@body)
               (setq ,flag #f))))))

(define-macro (acond2 . clauses)
  (if (null? clauses)
      '()
      (let ((cl1 (car clauses))
            (val (gensym))
            (win (gensym)))
        `(receive (,val ,win) ,(car cl1)
           (if (or ,val ,win)
               (let ((it ,val)) ,@(cdr cl1))
               (acond2 ,@(cdr clauses)))))))

;; (define-macro (fn expr) `,(rbuild expr))

;; (define (rbuild expr)
;;   (if (or (symbol? expr) (eq? (car expr) 'lambda))
;;       expr
;;       (if (eq? (car expr) 'compose)
;;           (build-compose (cdr expr))
;;           (build-call (car expr) (cdr expr)))))

;; (define (build-call op fns)
;;   (let ((g (gensym)))
;;     `(lambda (,g)
;;        (,op ,@(map (lambda (f)
;;                      `(,(rbuild f) ,g))
;;                    fns)))))

;; (define (build-compose fns)
;;   (let ((g (gensym)))
;;     `(lambda (,g)
;;        ,(letrec ((rec (lambda (fns)
;;                         (if (not (null? fns))
;;                             `(,(rbuild (car fns))
;;                               ,(rec (cdr fns)))
;;                             g))))
;;           (rec fns)))))

;; (define-macro (alrec rec . base)
;;   (let1 base (get-optional base '())
;;     (let ((gfn (gensym)))
;;       `(lrec (lambda (it ,gfn)
;;                (letrec ((rec (lambda () (,gfn))))
;;                  ,rec))
;;              ,base))))

;; (define-macro (on-cdrs rec base . lsts)
;;   `((alrec ,rec (lambda _ ,base)) ,@lsts))

;; (define-macro (atrec rec . base)
;;   (let1 base (get-optional base 'it)
;;     (let ((lfn (gensym)) (rfn (gensym)))
;;       `(trec (lambda (it ,lfn ,rfn)
;;                (letrec ((left (lambda () (,lfn)))
;;                         (right (lambda () (,rfn))))
;;                  ,rec))
;;              (lambda (it) ,base)))))

;; (define-macro (on-trees rec base . trees)
;;   `((atrec ,rec ,base) ,@trees))

;; #|
;; ; R5RS like
;; (define (force obj) (obj))

;; (define-macro (delay expr)
;;   `(make-promise (lambda () ,expr)))

;; (define (make-promise proc)
;;   (let ((result-ready? #f)
;;         (result #f))
;;     (lambda ()
;;       (if result-ready?
;;           result
;;           (let ((x (proc)))
;;             (if result-ready?
;;                 result
;;                 (begin (set! result-ready? #t)
;;                        (set! result x)
;;                        result)))))))
;; |#

;; (define *unforced* (gensym))
;; (define (make-delay forced closure)
;;   (cons forced closure))
;; (define delay-forced car)
;; (define delay-closure cdr)
;; (define (delay? p)
;;   (if (and (pair? p)
;;            (eq? (delay-forced p) *unforced*))
;;       #t #f))

;; (define-macro (delay expr)
;;   (let ((self (gensym)))
;;     `(let ((,self (,make-delay *unforced* #f)))
;;        (set! (,delay-closure ,self)
;;              (lambda ()
;;                (set! (,delay-forced ,self) ,expr)
;;                (,delay-forced ,self)))
;;        ,self)))

;; (define (force x)
;;   (if (delay? x)
;;       ((delay-closure x))
;;       (delay-forced x)))

;; #|
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; [0] expected usage form.
;; (abbrev mvbind multiple-value-bind)

;; [1] [0] is extracted to this.
;; (define-macro (mvbind . args)
;;   `(multiple-value-bind ,@args))

;; [2] abbrev's arguments take out backquote expression.
;; (define-macro (mvbind . args)
;;   (let ((name 'multiple-value-bind))
;;     `(,name ,@args)))

;; [3] rename abbrev's arguments.
;; `(define-macro (,short . args)
;;    (let ((name ',long))
;;      `(,name ,@args)))

;; [4] pull off names.
;; `(define-macro (,short . args)
;;    `(,',long ,@args))

;; [5] finish.
;; (define-macro (abbrev short long)
;;   `(define-macro (,short . args)
;;      `(,',long ,@args)))
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; |#

(define-macro (abbrev short long)
  `(define-macro (,short . args)
     `(,',long ,@args)))

;; (define-macro (abbrevs . names)
;;   `(begin
;;      ,@(map (lambda (pair)
;;               `(abbrev ,@pair))
;;             (group names 2))))

;; #|
;; [0]
;; (propmacro color)
;; [1]
;; (define-macro (color obj)
;;   `(get ,obj 'color))
;; [2]
;; (define-macro (color obj)
;;   (let ((name 'color))
;;     `(get ,obj ',name)))
;; [3]
;; `(define-macro (,propname obj)
;;    (let ((name ',propname))
;;      `(get ,obj ',name)))
;; [4]
;; `(define-macro (,propname obj)
;;    `(get ,obj ',',propname))
;; [5]
;; (define-macro (propmacro propname)
;;   `(define-macro (,propname obj)
;;      `(get ,obj ',',propname)))
;; |#

;; (define (get obj prop)
;;   (cdr (assoc prop obj)))

;; (define-macro (propmacro propname)
;;   `(define-macro (,propname obj)
;;      `(get ,obj ',',propname)))

;; (define-macro (propmacros . names)
;;   `(begin
;;      ,@(map (lambda (name)
;;               `(propmacro ,name))
;;             names)))

;; (define-macro (a+ . args)
;;   (a+expand args '()))

;; (define (a+expand args syms)
;;   (if (not (null? args))
;;       (let ((sym (gensym)))
;;         `(let* ((,sym ,(car args))
;;                 (it ,sym))
;;            ,(a+expand (cdr args) (append syms (list sym)))))
;;       `(+ ,@syms)))

;; (define-macro (alist . args)
;;   (alist-expand args '()))

;; (define (alist-expand args syms)
;;   (if (not (null? args))
;;       (let ((sym (gensym)))
;;         `(let* ((,sym ,(car args))
;;                 (it ,sym))
;;            ,(alist-expand (cdr args) (append syms (list sym)))))
;;       `(list ,@syms)))

;; (define (pop-symbol sym)
;;   (string->symbol (subseq (symbol->string sym) 1)))

;; ;; calls is function like as +, list above examples.
;; ;; if you don't write calls, you make a 'name'carefully.
;; ;;
;; (define-macro (defanaph name . calls)
;;   (let1 calls (get-optional calls #f)
;;     (let ((calls (or calls (pop-symbol name))))
;;       `(define-macro (,name . args)
;;          (anaphex args (list ',calls))))))

;; (define (anaphex args expr)
;;   (if (not (null? args))
;;       (let ((sym (gensym)))
;;         `(let* ((,sym ,(car args))
;;                 (it ,sym))
;;            ,(anaphex (cdr args) (append expr (list sym)))))
;;       expr))

;; (define-macro (def-anaph name . calls-rule)
;;   (let-keywords* calls-rule ((calls :call #f)
;;                              (rule :rule :all))
;;     (let* ((opname (or calls (pop-symbol name)))
;;            (body (case rule
;;                    ((:all) `(anaphex1 args '(,opname)))
;;                    ((:first) `(anaphex2 ',opname args))
;;                    ((:place) `(anaphex3 ',opname args)))))
;;       `(define-macro (,name . args)
;;          ,body))))

;; (define (anaphex1 args call)
;;   (if (not (null? args))
;;       (let ((sym (gensym)))
;;         `(let* ((,sym ,(car args))
;;                 (it ,sym))
;;            ,(anaphex1 (cdr args)
;;                       (append call (list sym)))))
;;       call))

;; (define (anaphex2 op args)
;;   `(let ((it ,(car args))) (,op it ,@(cdr args))))

;; (define (anaphex3 op args)
;;   `(_! (lambda (it) (,op it ,@(cdr args))) ,(car args)))

;; (define-macro (dbind pat seq . body)
;;   (let ((gseq (gensym)))
;;     `(let ((,gseq ,seq))
;;        ,(dbind-ex (destruc pat gseq atom?) body))))

;; (define (destruc pat seq . atom?-n)
;;   (let-optionals* atom?-n ((pred atom?)
;;                            (n 0))
;;     (if (null? pat)
;;         '()
;;         (let ((rest (cond ((pred pat) pat)
;;                           ((eq? (car pat) :rest) (cadr pat))
;;                           ((eq? (car pat) :body) (cadr pat))
;;                           (else '()))))
;;           (if (not (null? rest))
;;               `((,rest (,subseq ,seq ,n)))
;;               (let ((p (car pat))
;;                     (rec (destruc (cdr pat) seq pred (+ n 1))))
;;                 (if (pred p)
;;                     (cons `(,p (ref ,seq ,n))
;;                           rec)
;;                     (let ((var (gensym)))
;;                       (cons (cons `(,var (ref ,seq ,n))
;;                                   (destruc p var pred))
;;                             rec)))))))))

;; (define (dbind-ex binds body)
;;   (if (null? binds)
;;       `(begin ,@body)
;;       `(let ,(map (lambda (b)
;;                     (if (pair? (car b))
;;                         (car b)
;;                         b))
;;                   binds)
;;          ,(dbind-ex (append-map (lambda (b)
;;                                   (if (pair? (car b))
;;                                       (cdr b) '()))
;;                                 binds)
;;                     body))))

;; (define-macro (with-matrix pats ar . body)
;;   (let ((gar (gensym)))
;;     `(let ((,gar ,ar))
;;        (let ,(let ((row -1))
;;                (append-map
;;                 (lambda (pat)
;;                   (inc! row)
;;                   (setq col -1)
;;                   (map (lambda (p)
;;                          `(,p (,array-ref ,gar
;;                                           ,row
;;                                           ,(inc! col))))
;;                        pat))
;;                 pats))
;;          ,@body))))

;; (define-macro (with-array pat ar . body)
;;   (let ((gar (gensym)))
;;     `(let ((,gar ,ar))
;;        (let ,(map (lambda (p)
;;                     `(,(car p) (,array-ref ,gar ,@(cdr p))))
;;                   pat)
;;          ,@body))))

;; #|
;; ;; I want to use symbol-macrolet.
;; ;;
;; (define-macro (with-places pat seq . body)
;;   (let ((gseq (gensym)))
;;     `(let ((,gseq ,seq))
;;        ,(wplac-ex (destruc pat gseq) body))))

;; (define (wplac-ex binds body)
;;   (if (null? binds)
;;       `(begin ,@body)
;;       `(letrec ,(map (lambda (b)
;;                        (if (pair? (car b))
;;                            (car b)
;;                            b))
;;                      binds)
;;          ,(wplac-ex (append-map (lambda (b)
;;                                   (if (pair? (car b))
;;                                       (cdr b)
;;                                       '()))
;;                                 binds)
;;                     body))))
;; |#

;; (define-macro (receive* forms expr . body)
;;   (let ((gs (gensym)))
;;     `(call-with-values (lambda _ ,expr)
;;        (lambda ,gs
;;          (apply (lambda ,forms ,@body)
;;                 (if (pair? ',forms)
;;                     (,take* ,gs (length ',forms) #t #f)
;;                     ,gs))))))

;; (define receive receive*)

;; (define (match-fn x y . binds)
;;   (acond2
;;    ((or (eq? x y) (eq? x '_) (eq? y '_)) (values binds #t))
;;    ((binding x binds) (apply match-fn it y binds))
;;    ((binding y binds) (apply match-fn x it binds))
;;    ((varsym? x) (values (cons (cons x y) binds) #t))
;;    ((varsym? y) (values (cons (cons y x) binds) #t))
;;    ((and (pair? x) (pair? y) (apply match-fn (car x) (car y) binds))
;;     (apply match-fn (cdr x) (cdr y) it))
;;    (#t (values #f #f))))

;; (define (varsym? x)
;;   (and (symbol? x) (equal? (string-ref (symbol->string x) 0) #\?)))

;; (define (binding x binds)
;;   (letrec ((recbind (lambda (x binds)
;;                       (aif (assoc x binds)
;;                            (if it
;;                                (or (recbind (cdr it) binds) it))
;;                            it))))
;;     (let ((b (recbind x binds)))
;;       (values (if b (cdr b) b) b))))

;; (define-macro (if-match-ls pat seq then . else)
;;   (let1 else (get-optional else '())
;;     `(aif2 (match-fn ',pat ,seq)
;;            (let ,(map (lambda (v)
;;                         `(,v (,binding ',v it)))
;;                       (vars-in then atom?))
;;              ,then)
;;            ,else)))

;; (define (vars-in expr . pred)
;;   (let1 pred (get-optional pred atom?)
;;     (if (pred expr)
;;         (if (var? expr) (list expr) '())
;;         (lset-union eq? (vars-in (car expr) atom?)
;;                     (vars-in (cdr expr) atom?)))))

;; (define (var? x)
;;   (and (symbol? x) (eq? (string-ref (symbol->string x) 0) #\?)))

;; ;; -- if-match macro --
;; ;; special define for gensym? procedure.
;; ;;
;; #|
;; (define original-gensym
;;   (if (symbol-bound? 'original-gensym)
;;     original-gensym
;;     gensym))
;; (define gensym
;;   (let ((*gensyms* '()))
;;     (lambda args
;;       (cond
;;        ((null? args)
;;         (begin
;;           (set! *gensyms* (cons (original-gensym) *gensyms*))
;;           (car *gensyms*)))
;;        ((string? (car args))
;;         (begin
;;           (set! *gensyms* (cons (apply original-gensym args) *gensyms*))
;;           (car *gensyms*)))
;;        ((eq? 'syms (car args)) *gensyms*)
;;        (else (error "ERROR: gensym has no such message." args))))))
;; (define (gensym? s)
;;   (if (member s (gensym 'syms) eq?)
;;       #t #f))
;; |#

;; (define-macro (if-match pat seq then . else)
;;   (let1 else (get-optional else '())
;;     `(let ,(map (lambda (v) `(,v ',(gensym)))
;;                 (vars-in pat simple?))
;;        (pat-match ,pat ,seq ,then ,else))))

;; (define-macro (pat-match pat seq then else)
;;   (if (simple? pat)
;;       (match1 `((,pat ,seq)) then else)
;;       (with-gensyms (gseq gelse)
;;                     `(letrec ((,gelse (lambda () ,else)))
;;                        ,(gen-match (cons (list gseq seq)
;;                                          (destruc pat gseq simple?))
;;                                    then
;;                                    `(,gelse))))))
;; (define (simple? x)
;;   (or (atom? x) (eq? (car x) 'quote)))

;; (define (gen-match refs then else)
;;   (if (null? refs)
;;       then
;;       (let ((then (gen-match (cdr refs) then else)))
;;         (if (simple? (caar refs))
;;             (match1 refs then else)
;;             (gen-match (car refs) then else)))))

;; (define (match1 refs then else)
;;   (dbind ((pat expr) . rest) refs
;;          (cond ((gensym? pat)
;;                 `(let ((,pat ,expr))
;;                    (if (and (is-a? ,pat <sequence>)
;;                             ,(length-test pat rest))
;;                        ,then
;;                        ,else)))
;;                ((eq? pat '_) then)
;;                ((var? pat)
;;                 (let ((ge (gensym)))
;;                   `(let ((,ge ,expr))
;;                      (if (or (,gensym? ,pat) (equal? ,pat ,ge))
;;                          (let ((,pat ,ge)) ,then)
;;                          ,else))))
;;                (else `(if (equal? ,pat ,expr) ,then ,else)))))

;; (define (gensym? s)
;;   (and (symbol? s)
;;        (not (eq? s (string->symbol (symbol->string s))))))

;; (define (length-test pat rest)
;;   (define (last lst)
;;     (if (null? lst) lst
;;         (last-pair lst)))
;;   (define (kaadar lst)
;;     (if (null? lst)
;;         lst
;;         (caadar lst)))
;;   (let ((fin (kaadar (last rest))))
;;     (if (or (pair? fin) (eq? fin 'ref))
;;         `(= (,size-of ,pat) ,(size-of rest))
;;         `(> (,size-of ,pat) ,(- (size-of rest) 2)))))


;; (provide "onlisp")

;; ;; Local variables:
;; ;; mode: scheme
;; ;; end:
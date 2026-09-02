#lang racket 
(require rkanren)



;http://codepad.org/6uu28twJ


;;;  'trace-vars' can be used to print the values of selected variables
;;;  in the substitution.
(define-syntax trace-vars
  (syntax-rules ()
    ((_ title x ...)
     (lambdag@ (s)
       (begin
         (printf "~a~n" title)
         (for-each (lambda (x_ t) 
                     (printf "~a = ~s~n" x_ t))
           `(x ...) (reify (walk* `(,x ...) s)))
         (unit s))))))


(define *s (lambda (s) (unit s)))

(define *u (lambda (s) (mzero)))

(display (run #f (q) (== #t q)))
(newline)
(display (run #f (q) *s))
(newline)
(display (run #f (q) *u))
(newline)

(display
 (run* (q)
   (fresh (r)
     (== 3 q)
     (trace-vars "What it is!" q r))))


;;http://codepad.org/96FTq50M

(define r (var 'r))

(cout (appende `(い ろ) `(は に) r))  (newline) (newline)

(define a (var 'a))
(define b (var 'b))

(cout (appende a b `(い ろ は に)))



;;http://codepad.org/qJcs4es4

(define 名前
  '(("ソクラテス" . "人")
    ("アリストテレス" . "人")
    ("飯島愛" . "天使")
    ("HAL9000" . "ロボット")))

(define 名前?
       (lambda (l a d)
	 (fresh (p)
	   (choose l a d))))

(define 生死
  '(("人" . "死ぬ")
    ("天使" . "不滅")
    ("ロボット" . "壊れる")))

(define 生死?
       (lambda (l a d)
	 (fresh (p)
	   (choose l a d))))

(define 死ぬの? 
 (lambda (a live_or_die)
   (run* (out)
        (fresh (d)
          (名前? 名前 a d)
          (生死? 生死 d live_or_die)
          (conso a live_or_die out)))))

(define a (var 'a))
(define d (var 'd))

(cout (死ぬの? a "死ぬ"))  (newline) (newline)
(cout (死ぬの? a "不滅"))  (newline) (newline)
(cout (死ぬの? a d))



;;;;

(define a (var 'a))
(define d (var 'd))

(run*
 (q)
 (== d a)
 (== q `(,a ,d))
 (== a 1)
 );;=>(1 1)


(let ([x (var 'x)]
      [y (var 'x)])
  (display (eq? x y)) ;#f
  (run*
   (q)
   ;(== x y)
   (== q `(,x ,y))
   (== x 1)
 ));;=>(1 _.0 )
  


(run* (q)
      (fresh (x y)
	     (== q `(,x ,y ))))


(run* (q)
      (fresh (x y)
	     (== y q)
	     (== q `(,x ,y ))))
(member 1 '(0 1 3 4))
(assq ()

(assoc 3 (list (list 1 2) (list 3 4) (list 5 6)))
(member '(3 4) (list (list 1 2) (list 3 4) (list 5 6)))

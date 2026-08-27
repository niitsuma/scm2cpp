#lang racket

(provide
 s-hashed? s-ref s-alist
 recursive-representation? make-recursive-representation
 var var? rhs lhs lambdag@ walk walk* mzerog unitg
    choiceg lambdaf@ : take empty-f conde conda ifa
    condu ifu fresh project onceo succeed fail prt

    mplusg*
    bindg*

    )

(require racket/pretty)

;; The substitution is either a plain association list (the reifier's
;; naming environment) or a pair of that list with a hash of the same
;; bindings, which is what walk reads; ck.scm builds the paired form.
(define (s-hashed? S) (and (pair? S) (hash? (cdr S))))
(define s-none (vector 'none))
(define (s-ref S u)
  (if (s-hashed? S)
      (let ((v (hash-ref (cdr S) u s-none)))
        (if (eq? v s-none) #f (cons u v)))
      (assq u S)))
(define (s-alist S) (if (s-hashed? S) (car S) S))

;; (define var
;;   (lambda (x)
;;     (vector x)))

;; (define var?
;;   (lambda (x)
;;     (vector? x)))

(require srfi/9)

(define-record-type *logical-variable*
  (make-logical-variable name) logical-variable?
  (name logical-variable-id))

(define var  make-logical-variable)
(define var? logical-variable?)


(define rhs
  (lambda (x)
    (cdr x)))

(define lhs
  (lambda (x)
    (car x)))

(define-syntax :
  (lambda (x)
    (raise-syntax-error 'mk "misplaced aux keyword" x)))

(define-syntax lambdag@
  (syntax-rules (:)
    ((_ (a : s c) e)
     (lambda (a) (let ((s (car a)) (c (cdr a))) e)))
    ((_ (a) e) (lambda (a) e))))

(define-syntax lambdaf@
  (syntax-rules ()
    ((_ () e) (lambda () e))))

;; A binding may be self-referential, written (==> x t) after Niitsuma's
;; recursive miniKanren: t is the term and x the variable inside it that
;; stands for the whole. Both walks carry the variables already entered
;; and stop on meeting one again.
(define (recursive-representation? l)
  (if (and (pair? l) (eq? (car l) '==>) (pair? (cdr l)) (var? (cadr l)))
      (cadr l)
      #f))
(define (make-recursive-representation x t) (list '==> x t))

(define walk
  (lambda (v s)
    (let walk ((v v) (seen '()))
      (cond
        ((var? v)
         (let ((a (s-ref s v)))
           (cond
             ((not a) v)
             ((memq v seen) v)
             (else (walk (rhs a) (cons v seen))))))
        (else v)))))

(define walk*
  (lambda (w s)
    (let walk* ((w w) (seen '()))
      (let ((v (walk w s)))
        (cond
          ((var? v) v)
          ((recursive-representation? v)
           => (lambda (x)
                (let* ((n (walk x s))
                       (x^ (if (symbol? n) n x)))
                  (if (memq x seen)
                      x^
                      (list '==> x^ (walk* (caddr v) (cons x seen)))))))
          ((pair? v)
           (cons (walk* (car v) seen)
                 (walk* (cdr v) seen)))
          (else v))))))

(define mzerog (lambda () #f)) ;;normal miniKanren (mzero) = #f as macro
(define unitg (lambdag@ (a) a));;=succeed
(define choiceg (lambda (a f) (cons a f))) ;;normal miniKanren as macro

(define succeed (lambdag@ (a) a))
(define fail (lambdag@ (a) (mzerog)))
(define prt (lambdag@ (a) (begin (pretty-print a) (unitg a))))

(define-syntax inc  ;;glue lambda
  (syntax-rules ()
    ((_ e) (lambdaf@ () e))))

;;e0-> on-zero , e2 -> on-one , e3 -> on-chice
(define-syntax case-inf
  (syntax-rules ()
    ((_ e (() on-zero) ((f^) e1) ((a^) on-one) ((a f) on-chice))
     (let ((a-inf e))
       (cond
         ((not a-inf) on-zero)
         ((procedure? a-inf)  (let ((f^ a-inf)) e1));;not hvae in normal miniKanren
         ((not (and (pair? a-inf)
                    (procedure? (cdr a-inf))))
          (let ((a^ a-inf)) on-one))
         (else (let ((a (car a-inf)) (f (cdr a-inf))) 
                 on-chice)))))))

(define empty-f (lambdaf@ () (mzerog)))

(define take ;;body of run == map-inf normal mniKanren
  (lambda (n f)
    (cond
      ((and n (zero? n)) '())
      (else (case-inf (f)  ;;eval f when used in macro case-inf
              (() '())
              ((f) (take n f));;eval f again
              ((a) (cons a '()));;finish this choice. a=(f). ret=((f))
              ((a f) (cons a (take (and n (- n 1)) f))) ;;split choice, a=result of this chice. ret= (f0 . (take n-1 f1)
	      )))))

(define-syntax bindg*  ;;(bindg (bindg (bindg e g0) g1) ...)
  (syntax-rules ()
    ((_ e) e)
    ((_ e g0 g ...) (bindg* (bindg e g0) g ...))))


(define bindg
  (lambda (a-inf g)
    (case-inf a-inf
      (() (mzerog));;(lam #f)
      ((f) (inc (bindg (f) g)));(lam (bind (a-inf) g)
      ((a) (g a));;(g a-inf)
      ((a f) (mplusg (g a) (lambdaf@ () (bindg (f) g)))))))

(define-syntax conde
  (syntax-rules ()
    ((_ (g0 g ...) (g1 g^ ...) ...)
     (lambdag@ (a) 
       (inc 
         (mplusg* 
           (bindg* (g0 a) g ...)
           (bindg* (g1 a) g^ ...) ...))))))

(define-syntax mplusg* ;;(mplusg e0 (lam (mplusg e1..(lam e9)
  (syntax-rules ()
    ((_ e) e)
    ((_ e0 e ...)
     (mplusg e0 
       (lambdaf@ () (mplusg* e ...))))))
;;(mplusg* e0 e1)= (mplus e0 (lam() e1))=(e0 . lam (e1))
(define mplusg
  (lambda (a-inf f)
    (case-inf a-inf
      (() (f));;eval f <==split conde 
      ((f^) (inc (mplusg (f) f^)));= (lam (mplus (f) a-inf))
      ((a) (choiceg a f));;=(a-inf . f)
      ((a f^) (choiceg a (lambdaf@ () (mplusg (f) f^))));;=(a-inf0 .(lam(mplus (f) a-inf1)
)))

(define-syntax conda
  (syntax-rules ()
    ((_ (g0 g ...) (g1 g^ ...) ...)
     (lambdag@ (a)
       (inc
         (ifa ((g0 a) g ...)
           ((g1 a) g^ ...) ...))))))

(define-syntax ifa
  (syntax-rules ()
    ((_) (mzerog))
    ((_ (e g ...) b ...)
     (let loop ((a-inf e))
       (case-inf a-inf
         (() (ifa b ...))
         ((f) (inc (loop (f))))
         ((a) (bindg* a-inf g ...))
         ((a f) (bindg* a-inf g ...)))))))

(define-syntax condu
  (syntax-rules ()
    ((_ (g0 g ...) (g1 g^ ...) ...)
     (lambdag@ (a)
       (inc
         (ifu ((g0 a) g ...)
           ((g1 a) g^ ...) ...))))))

(define-syntax ifu
  (syntax-rules ()
    ((_) (mzerog))
    ((_ (e g ...) b ...)
     (let loop ((a-inf e))
       (case-inf a-inf
         (() (ifu b ...))
         ((f) (inc (loop (f))))
         ((a) (bindg* a-inf g ...))
         ((a f) (bindg* (unitg a) g ...)))))))

(define-syntax fresh
  (syntax-rules ()
    ((_ (x ...) g0 g ...)
     (lambdag@ (a)
       (inc
         (let ((x (var 'x)) ...)
           (bindg* (g0 a) g ...)))))))

(define-syntax project 
  (syntax-rules ()
    ((_ (x ...) g g* ...)  
     (lambdag@ (a : s c)
       (let ((x (walk* x s)) ...)
         ((fresh () g g* ...) a))))))

(define onceo (lambda (g) (condu (g))))

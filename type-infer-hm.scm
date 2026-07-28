#lang racket
;;;; Type inference by Hindley-Milner (algorithm W).
;;;; Same contract as derive-type, so it can be substituted for it.
;;;;
;;;;   (derive-type-hm expr-alpha env-init)
;;;;     -> (values env ret-type unknown-type-list)
;;;;
;;;; env is an association list of ((var . type) ...) and
;;;;   (fname lambda (argtype ...) rettype).
;;;; Type symbols come from type-symbols.scm (Int, Double, Bool, Void, ...).
;;;;
;;;; The relational (cKanren) implementation enumerates all solutions and does
;;;; not terminate on several similarly shaped recursive functions. This one
;;;; performs no search, only unification, and is near linear in practice.

(provide derive-type-hm)

(require srfi/1)
(require "type-symbols.scm")
(require "type-infer-util.scm")

;;;; ---------------- type variables and substitution ----------------

(define tvar-counter 0)
(define (fresh-tvar!)
  (set! tvar-counter (+ tvar-counter 1))
  (string->symbol (format "HMVar~a" tvar-counter)))
(define (tvar? t)
  (and (symbol? t) (regexp-match? #px"^HMVar[0-9]+$" (symbol->string t))))

(define subst (make-hasheq))

(define (walk t)
  (cond [(and (tvar? t) (hash-has-key? subst t)) (walk (hash-ref subst t))]
        [else t]))

(define (fun-type? t) (and (pair? t) (eq? (car t) 'lambda)))
;; Function types are (lambda (argtype ...) rettype)

(define (occurs? v t)
  (let ([t (walk t)])
    (cond [(eq? v t) #t]
          [(fun-type? t) (or (ormap (lambda (a) (occurs? v a)) (cadr t))
                             (occurs? v (caddr t)))]
          [else #f])))

;; number-type-order-list runs narrow to wide; return the wider of two.
(define (wider-number a b)
  (let loop ([rest number-type-order-list] [found #f])
    (cond [(null? rest) (or found a)]
          [(or (eq? (car rest) a) (eq? (car rest) b)) (loop (cdr rest) (car rest))]
          [else (loop (cdr rest) found)])))

(define (number-t? t) (and (memq t number-type-order-list) #t))

;; Unification. On failure returns #f rather than raising, leaving the type
;; variable unresolved.
(define (unify! a0 b0)
  ;; A type variable already bound to a numeric type is rebound when it meets a
  ;; wider one, which is what lets x in (* x x) become double once a later call
;; site says so.
  (cond
    [(and (tvar? a0) (hash-has-key? subst a0)
          (number-t? (walk a0)) (number-t? (walk b0)))
     (hash-set! subst a0 (wider-number (walk a0) (walk b0))) #t]
    [(and (tvar? b0) (hash-has-key? subst b0)
          (number-t? (walk b0)) (number-t? (walk a0)))
     (hash-set! subst b0 (wider-number (walk b0) (walk a0))) #t]
    [else (unify-walked! a0 b0)]))

(define (unify-walked! a b)
  (let ([a (walk a)] [b (walk b)])
    (cond
      [(eq? a b) #t]
      [(tvar? a) (cond [(occurs? a b) #f]
                       [else (hash-set! subst a b) #t])]
      [(tvar? b) (unify! b a)]
      ;; two numerics widen as C++ arithmetic conversion widens them
      [(and (number-t? a) (number-t? b)) #t]
      [(and (fun-type? a) (fun-type? b)
            (= (length (cadr a)) (length (cadr b))))
       (and (andmap unify! (cadr a) (cadr b))
            (unify! (caddr a) (caddr b)))]
      [(and (vec-type? a) (vec-type? b)) (unify! (caddr a) (caddr b))]
      [(and (list-type? a) (list-type? b) (= (length a) (length b)))
       (andmap unify! (cdr a) (cdr b))]
      [(and (stream-type? a) (stream-type? b)) (unify! (cadr a) (cadr b))]
      [else #f])))

(define (vec-type? t) (and (pair? t) (eq? (car t) 'make-vector)))
(define (list-type? t) (and (pair? t) (eq? (car t) 'list)))


(define (stream-type? t) (and (pair? t) (eq? (car t) 'scm2cpp-stream)))
(define (resolve t)
  (let ([t (walk t)])
    (cond [(fun-type? t) (list 'lambda (map resolve (cadr t)) (resolve (caddr t)))]
          [(vec-type? t) (list 'make-vector (cadr t) (resolve (caddr t)))]
          [(list-type? t) (cons 'list (map resolve (cdr t)))]
          [(stream-type? t) (list 'scm2cpp-stream (resolve (cadr t)))]
          [else t])))

;;;; ---------------- environment ----------------
;; The internal environment is a hash; it is converted to the association list
;; form on the way out.

;; The code generator looks up parameter and local types in the same
;; environment, so every binding is recorded.
(define all-bindings (make-hasheq))
(define (env-set env x t)
  (hash-set! all-bindings x t)
  (hash-set env x t))
(define (env-ref env x)
  (if (hash-has-key? env x) (hash-ref env x) #f))

;; Import the existing initial environment.
;;   Both (x . Int) and (f lambda (t ...) r) forms occur.
;; Whether this is a type shape HM understands. Passing an unknown shape
;; through makes the code generator fail in symbol->string.
(define (understood-type? t)
  (and (pair? t)
       (memq (car t) '(lambda make-vector make-list list scm2cpp-stream cons))
       #t))

(define (import-init-env env-init)
  (for/fold ([h (make-immutable-hasheq)]) ([kv env-init])
    (cond
      [(and (pair? kv) (pair? (cdr kv)) (eq? (cadr kv) 'lambda))
       (env-set h (car kv) (list 'lambda (caddr kv) (cadddr kv)))]
      [(pair? kv)
       ;; The initial environment represents an unknown type by the variable name
;; itself; replace those with fresh type variables.
       ;; Shapes HM cannot interpret are also replaced.
       (env-set h (car kv)
                (let ([t (cdr kv)])
                  (cond [(eq? t (car kv)) (fresh-tvar!)]
                        [(symbol? t) t]
                        [(understood-type? t) t]
                        [else (fresh-tvar!)])))]
      [else h])))

;;;; ---------------- operators ----------------

(define numeric-ops '(+ - * max min))
(define int-ops '(quotient remainder modulo))
(define compare-ops '(= < > <= >= eq? eqv? equal? char=? string=?))
(define float-ops '(sqrt sin cos tan exp log asin acos atan exact->inexact))
(define pred-ops '(zero? even? odd? negative? positive? null? pair? number? string? symbol?))

;;;; ---------------- inference ----------------

(define (infer env e)
  (cond
    [(exact-integer? e) Int]
    [(and (real? e) (inexact? e)) Double]
    [(boolean? e) Bool]
    [(string? e) String]
    [(char? e) Char]
    [(symbol? e) (or (env-ref env e) (let ([t (fresh-tvar!)]) t))]
    [(null? e) Null]
    [(pair? e)
     (match e
       [`(quote ,_) Symbol]
       [`(begin ,body ...) (infer-body env body)]
       [`(if ,c ,t ,f)
        (unify! (infer env c) Bool)
        (let ([tt (infer env t)] [tf (infer env f)])
          ;; In statement position one branch may not yield a value; do not force a match
          (cond [(eq? (walk tt) Void) (resolve tf)]
                [(eq? (walk tf) Void) (resolve tt)]
                [else (unify! tt tf) (resolve tt)]))]
       [`(if ,c ,t) (unify! (infer env c) Bool) (infer env t) Void]
       [`(cond) Void]
       [`(cond (else ,body ...)) (infer-body env body)]
       [`(cond (,c ,body ...) ,rest ...)
        (unless (eq? c 'else) (unify! (infer env c) Bool))
        (let ([tt (infer-body env body)] [tr (infer env `(cond ,@rest))])
          (unless (eq? (walk tr) Void) (unify! tt tr))
          (resolve tt))]
       [`(when ,c ,body ...) (unify! (infer env c) Bool) (infer-body env body) Void]
       [`(unless ,c ,body ...) (unify! (infer env c) Bool) (infer-body env body) Void]
       
       [`(make-promise ,x) (infer env x)]
       [`(delay ,x)
        (let ([t (infer env x)]) (list 'lambda '() (resolve t)))]
       [`(force ,x)
        (let ([xt (walk (infer env x))])
          (if (fun-type? xt) (caddr xt) (fresh-tvar!)))]
       [`(not ,x) (infer env x) Bool]
       [`(set! ,(? symbol? x) ,v)
        (let ([tx (or (env-ref env x) (fresh-tvar!))])
          (unify! tx (infer env v)) Void)]
       [`(display ,x ,_ ...) (infer env x) Void]
       [`(newline ,_ ...) Void]
       [`(let ((,xs ,vs) ...) ,body ...)
        (let* ([ts (map (lambda (v) (infer env v)) vs)]
               [env2 (for/fold ([en env]) ([x xs] [t ts]) (env-set en x t))])
          (infer-body env2 body))]
       [`(let ,(? symbol? name) ((,xs ,vs) ...) ,body ...)
        ;; Named let, treated as monomorphic recursion.
        (let* ([ts (map (lambda (v) (infer env v)) vs)]
               [rt (fresh-tvar!)]
               [env2 (for/fold ([en env]) ([x xs] [t ts]) (env-set en x t))]
               [env3 (env-set env2 name (list 'lambda ts rt))])
          (unify! rt (infer-body env3 body))
          (resolve rt))]
       [`(letrec ((,xs ,vs) ...) ,body ...)
        (let* ([ts (map (lambda (_) (fresh-tvar!)) xs)]
               [env2 (for/fold ([en env]) ([x xs] [t ts]) (env-set en x t))])
          (for ([t ts] [v vs]) (unify! t (infer env2 v)))
          (infer-body env2 body))]
       [`(do ((,xs ,inits ,steps ...) ...) (,test ,res ...) ,body ...)
        (let* ([its (map (lambda (i) (infer env i)) inits)]
               [env2 (for/fold ([en env]) ([x xs] [t its]) (env-set en x t))])
          (for ([s steps] [t its]) (when (pair? s) (unify! t (infer env2 (car s)))))
          (infer env2 test)
          (infer-body env2 body)
          (if (pair? res) (infer env2 (car res)) Void))]
       [`(lambda (,ps ...) ,body ...)
        (let* ([pts (map (lambda (_) (fresh-tvar!)) ps)]
               [env2 (for/fold ([en env]) ([p ps] [t pts]) (env-set en p t))]
               [rt (infer-body env2 body)])
          (list 'lambda (map resolve pts) (resolve rt)))]
       ;; vectors
       
       
       [`(list ,es ...)
        (let ([ts (map (lambda (x) (infer env x)) es)])
          (if (null? ts) (list 'list) (cons 'list (map resolve ts))))]
       [`(make-list ,n ,init) (infer env n) (list 'make-list n (infer env init))]
       [`(car ,l)
        (let ([lt (walk (infer env l))])
          (cond [(stream-type? lt) (cadr lt)]
                [(and (pair? lt) (eq? (car lt) 'list) (pair? (cdr lt))) (cadr lt)]
                [(and (pair? lt) (eq? (car lt) 'make-list)) (caddr lt)]
                [else (fresh-tvar!)]))]
       [`(cdr ,l)
        (let ([lt (walk (infer env l))])
          (cond [(stream-type? lt) (list 'lambda '() lt)]   ; the delayed tail
                [(and (pair? lt) (eq? (car lt) 'list) (pair? (cdr lt)))
                 
                 (if (andmap (lambda (x) (equal? x (cadr lt))) (cdr lt))
                     lt
                     (cons 'list (cddr lt)))]
                [else (fresh-tvar!)]))]
       [`(cons ,a ,d)
        (let ([at (infer env a)] [dt (walk (infer env d))])
          (cond
            
            [(and (fun-type? dt) (null? (cadr dt)))
             (let ([st (list 'scm2cpp-stream (resolve at))])
               (unify! (caddr dt) st)
               st)]
            [(list-type? dt) (cons 'list (cons (resolve at) (cdr dt)))]
            [else (list 'cons (resolve at) dt)]))]
       [`(list-ref ,l ,i)
        (infer env i)
        (let ([lt (walk (infer env l))])
          (if (and (pair? lt) (eq? (car lt) 'list) (pair? (cdr lt))) (cadr lt) (fresh-tvar!)))]
       ;; Vector types use the generator's own form: (make-vector length elem).
       ;; A constant length becomes boost::array, otherwise std::vector.
       [`(make-vector ,n ,init)
        (infer env n)
        (list 'make-vector n (infer env init))]
       [`(vector ,es ...)
        (let ([ts (map (lambda (x) (infer env x)) es)])
          (list 'make-vector (length es) (if (pair? ts) (car ts) Double)))]
       [`(vector-length ,v) (infer env v) Int]
       [`(vector-ref ,v ,i)
        (infer env i)
        (let ([vt (walk (infer env v))])
          ;; return the element type when it is known
          (if (and (pair? vt) (eq? (car vt) 'make-vector)) (caddr vt) (fresh-tvar!)))]
       [`(vector-set! ,v ,i ,x)
        (let ([vt (walk (infer env v))] [xt (infer env x)])
          (infer env i)
          (when (and (pair? vt) (eq? (car vt) 'make-vector)) (unify! (caddr vt) xt))
          Void)]
       ;; numeric operators
       [`(/ ,args ...) (for-each (lambda (a) (infer env a)) args) Double]
       [`(,(? (lambda (o) (memq o int-ops)) _) ,args ...)
        (for-each (lambda (a) (infer env a)) args) Int]
       [`(,(? (lambda (o) (memq o numeric-ops)) _) ,args ...)
        ;; Bind arguments and result to one type; leave it open if undetermined.
        (let ([ts (map (lambda (a) (infer env a)) args)]
              [r (fresh-tvar!)])
          (for ([t ts]) (unify! r t))
          (walk r))]
       [`(,(? (lambda (o) (memq o float-ops)) _) ,args ...)
        (for-each (lambda (a) (infer env a)) args) Double]
       [`(,(? (lambda (o) (memq o compare-ops)) _) ,args ...)
        (let ([ts (map (lambda (a) (infer env a)) args)])
          (when (and (pair? ts) (pair? (cdr ts)))
            (for ([t (cdr ts)]) (unify! (car ts) t)))
          Bool)]
       [`(,(? (lambda (o) (memq o pred-ops)) _) ,args ...)
        (for-each (lambda (a) (infer env a)) args) Bool]
       [`(string-append ,args ...) (for-each (lambda (a) (infer env a)) args) String]
       ;; internal define (already registered at the head of the body)
       [`(define (,name ,ps ...) ,body ...)
        (let* ([ft0 (env-ref env name)]
               [ft (if (fun-type? ft0) ft0
                       (list 'lambda (map (lambda (_) (fresh-tvar!)) ps) (fresh-tvar!)))]
               [pts (cadr ft)] [rt (caddr ft)]
               [env2 (for/fold ([en env]) ([p ps] [t pts]) (env-set en p t))])
          (unify! rt (infer-body env2 body))
          Void)]
       [`(define ,(? symbol? name) ,v)
        (let ([t (or (env-ref env name) (fresh-tvar!))])
          (unify! t (infer env v)) Void)]
       ;; application
       [`(,f ,args ...)
        (let* ([ft (infer env f)]
               [ats (map (lambda (a) (infer env a)) args)]
               [rt (fresh-tvar!)])
          (unify! ft (list 'lambda ats rt))
          (resolve rt))]
       [_ (fresh-tvar!)])]
    [else (fresh-tvar!)]))

;; Infer a body. Internal defines are registered first so that later forms can
;; refer to them.
(define (infer-body env body)
  (define env2
    (for/fold ([en env]) ([e body])
      (match e
        [`(define (,name ,ps ...) ,_ ...)
         (env-set en name (list 'lambda (map (lambda (_) (fresh-tvar!)) ps) (fresh-tvar!)))]
        [`(define ,(? symbol? name) ,_) (env-set en name (fresh-tvar!))]
        [_ en])))
  (for/fold ([t Void]) ([e body]) (infer env2 e)))

;;;; ---------------- entry point ----------------

(define (derive-type-hm expr env-init)
  (set! subst (make-hasheq))
  (set! all-bindings (make-hasheq))
  (define env0 (import-init-env env-init))
  ;; Register top-level defines first, for recursion and mutual recursion
  (define forms (if (and (pair? expr) (eq? (car expr) 'begin)) (cdr expr) (list expr)))
  (define env1
    (for/fold ([en env0]) ([f forms])
      (match f
        [`(define (,name ,ps ...) ,_ ...)
         (if (fun-type? (env-ref en name)) en
             (env-set en name (list 'lambda (map (lambda (_) (fresh-tvar!)) ps) (fresh-tvar!))))]
        [`(define ,(? symbol? name) ,_)
         (if (env-ref en name) en (env-set en name (fresh-tvar!)))]
        [_ en])))
  ;; Unification is monotone, so repeating a few times propagates information
  ;; so that x in (square x) becomes double once a later (square guess) is seen.
  (define ret
    (for/fold ([t Void]) ([i (in-range 3)])
      (for/fold ([t2 Void]) ([f forms]) (infer env1 f))))
  ;; Convert back to the existing form; unresolved type variables become Unknown.
  ;; Remaining type variables are mapped to Unknown-Type symbols, following the
  ;; existing convention: the generator turns those into template parameters.
  (define unknowns '())
  (define tvar->unknown (make-hasheq))
  (define (export t)
    (let ([t (walk t)])
      (cond [(tvar? t)
             (let ([u (hash-ref! tvar->unknown t (lambda () (gensym 'Unknown-Type)))])
               (set! unknowns (cons u unknowns))
               u)]
            [(fun-type? t) (list 'lambda (map export (cadr t)) (export (caddr t)))]
            [(vec-type? t) (list 'make-vector (cadr t) (export (caddr t)))]
            [(list-type? t) (cons 'list (map export (cdr t)))]
            [(stream-type? t) (list 'scm2cpp-stream (export (cadr t)))]
            [else t])))
  ;; all-bindings records every env-set, later bindings winning.
  ;; Overlaying env1 afterwards would reinstate stale types, so it is not done.
  (define env-out
    (for/list ([x (hash-keys all-bindings)])
      (let ([t (export (hash-ref all-bindings x))])
        (if (fun-type? t)
            (list x 'lambda (cadr t) (caddr t))
            (cons x t)))))
  (values env-out (export ret) (delete-duplicates unknowns)))

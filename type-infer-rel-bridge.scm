#lang racket
;;;; The bridge from the relational inferencer to the translator.
;;;;
;;;; SCM2CPP_RELATIONAL=1 (or --inference relational) used to select the
;;;; original cKanren-based derivation. It now tries this bridge first:
;;;; the program's definitions go through type-infer-rel.scm -- shapes,
;;;; recursive stream types and all -- and what comes back is converted
;;;; into the vocabulary the emitter already reads. Where this pass
;;;; cannot type the program, or does not do so inside its time budget
;;;; (SCM2CPP_REL_BUDGET seconds, default 300), the caller falls back to
;;;; the old derivation, so nothing that worked stops working.
;;;;
;;;; The conversion states the division of labour: shapes come from the
;;;; relation, widths do not. A numeric position becomes an Unknown-Type
;;;; symbol -- the convention the generator turns into a template
;;;; parameter -- so square arrives as the template function it should
;;;; be, and a local whose type is such a symbol is declared auto. A
;;;; vector's literal extent is kept and an open one stays open, which
;;;; is std::array against std::vector downstream. A stream converts
;;;; through type->nominal to (scm2cpp-stream T). An unguarded recursive
;;;; type -- a circular list as plain data -- refuses conversion, and
;;;; the refusal falls back like any other failure.

(provide derive-type-rel)

(require "type-infer-rel.scm"
         "type-symbols.scm")

;; ------------------------------------------------- old vocabulary -> gamma

(define (old->rel t)
  (cond
    [(memq t number-type-order-list) 'num]
    [(eq? t Bool) 'bool]
    [(eq? t Void) 'void]
    [(eq? t String) 'string]
    [(and (pair? t) (eq? (car t) 'lambda))
     (let ([as (map old->rel (cadr t))] [r (old->rel (caddr t))])
       (and (andmap values as) r `(-> ,as ,r)))]
    [else #f]))

(define (env->gamma env-type)
  (for/fold ([g '()]) ([kv env-type])
    (cond
      [(and (pair? kv) (pair? (cdr kv)) (eq? (cadr kv) 'lambda)
            (old->rel (cons 'lambda (cddr kv))))
       => (lambda (ft) (cons (list (car kv) ': ft) g))]
      [(and (pair? kv) (not (pair? (cdr kv))) (old->rel (cdr kv)))
       => (lambda (t) (cons (list (car kv) ': t) g))]
      [else g])))

;; ------------------------------------------------- rel types -> old ones

;; Reified variables (_.0 and friends) share one Unknown per spelling, so
;; a genuinely polymorphic link survives; each bare num is its own Unknown,
;; the width to be settled at the call site as a template argument is.
(define (make-converter)
  (define unknowns '())
  (define shared (make-hash))
  (define (fresh-unknown!)
    (let ([u (gensym 'Unknown-Type)]) (set! unknowns (cons u unknowns)) u))
  (define (shared-unknown! v)
    (hash-ref! shared v (lambda () (fresh-unknown!))))
  (define (conv t)
    (cond
      [(eq? t 'num) (fresh-unknown!)]
      [(eq? t 'int-fixed) Int]
      [(eq? t 'bool) Bool]
      [(eq? t 'void) Void]
      [(eq? t 'string) String]
      [(and (symbol? t) (regexp-match? #px"^_\\." (symbol->string t)))
       (shared-unknown! t)]
      [(pair? t)
       (case (car t)
         [(->) `(lambda ,(map conv (cadr t)) ,(conv (caddr t)))]
         [(vec) `(make-vector ,(if (number? (cadr t)) (cadr t) (shared-unknown! (cadr t)))
                              ,(conv (caddr t)))]
         [(pair) `(cons ,(conv (cadr t)) ,(conv (caddr t)))]
         [(scm2cpp-stream) `(scm2cpp-stream ,(conv (cadr t)))]
         [(list) `(list ,@(map conv (cdr t)))]
         [else (error 'rel->old "no old spelling for ~s" t)])]
      [else (error 'rel->old "no old spelling for ~s" t)]))
  (values conv (lambda () unknowns)))

;; ------------------------------------------------------------- the bridge

(define (run/budget thunk secs)
  (define ch (make-channel))
  (define th (thread (lambda ()
                       (channel-put ch (with-handlers ([(lambda (e) #t) (lambda (e) #f)])
                                         (thunk))))))
  (define r (sync/timeout secs ch))
  (unless r (kill-thread th))
  (and r r))

(define (derive-type-rel expr env-type)
  (define forms (if (and (pair? expr) (eq? (car expr) 'begin)) (cdr expr) (list expr)))
  (define defines
    (filter (lambda (f) (and (pair? f) (memq (car f) '(define define-macro)))) forms))
  (define budget
    (let ([b (getenv "SCM2CPP_REL_BUDGET")])
      (or (and b (string->number b)) 300)))
  (and
   (pair? defines)
   (let ([env (run/budget
               (lambda () (infer-program defines (env->gamma env-type)))
               budget)])
     (and env
          (with-handlers ([(lambda (e) #t) (lambda (e) #f)])  ; refusal -> fallback
            (let-values ([(conv unknowns-of) (make-converter)])
              (define env-out
                (for/list ([e env])
                  ;; main is the one function that may not be a template:
                  ;; C++ gives its signature, so a numeric return is int.
                  (let* ([main? (eq? (car e) 'main)]
                         [t0 (type->nominal (cdr e))]
                         [t0 (if (and main? (pair? t0) (eq? (car t0) '->)
                                      (eq? (caddr t0) 'num))
                                 (list '-> (cadr t0) 'int-fixed)
                                 t0)]
                         [t (conv t0)])
                    (if (and (pair? t) (eq? (car t) 'lambda))
                        (list (car e) 'lambda (cadr t) (caddr t))
                        (cons (car e) t)))))
              (list env-out Void (remove-duplicates (unknowns-of)))))))))

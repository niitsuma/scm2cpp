#lang racket
;;;; User bindings for custom C++ templates.
;;;;
;;;; SCM2CPP_BINDING names a file that declares how a header the user
;;;; supplies -- a matrix class, say -- is seen from Scheme: a type
;;;; constructor for the inference, an operation table for the code
;;;; generator, a pure Scheme model of each operation, and at least one
;;;; test program. The declarations are data; nothing in the file is
;;;; executed by loading it. The models are Scheme code, but they run only
;;;; inside the checking gate (binding-check.rkt), where running them is
;;;; the point -- the same trust as compiling the user's own program.
;;;;
;;;;   (deftype matrix
;;;;     (cpp "foo::Matrix< ~a >")     ; C++ spelling; ~a per type argument
;;;;     (header "\"foo.hpp\""))       ; include emitted when the type is used
;;;;
;;;;   (defop mat-ref
;;;;     (sig ((matrix double) int int) double)
;;;;     (cpp "~a.at(~a,~a)")          ; one ~a per operand, in order
;;;;     (mutates))                    ; argument positions written to
;;;;
;;;;   (model mat-ref (lambda (m i j) ...))   ; pure Scheme reference
;;;;
;;;;   (binding-test FORM ... (main))         ; complete program, prints
;;;;
;;;; Scalar type names in sigs: int double bool void. A compound type is
;;;; (TYPENAME scalar ...) for a deftype'd TYPENAME.

(require "type-symbols.scm")

(provide load-binding! binding-loaded?
         binding-type? binding-type-cpp binding-type-header
         binding-op? binding-op-sig-args binding-op-sig-ret
         binding-op-cpp binding-op-headers binding-op-mutates
         binding-models binding-tests)

(define types (make-hasheq))    ; name -> (vector cpp-format header)
(define ops (make-hasheq))      ; name -> (vector sig-args sig-ret cpp mutates)
(define models '())             ; alist name -> lambda-sexp
(define tests '())              ; list of programs (lists of forms)
(define loaded #f)

(define (binding-loaded?) loaded)

;; Sig types as written -> the inference's own symbols. The internal type
;; symbols are gensyms from type-symbols.scm, not the literal names, so the
;; identifiers themselves must be used here.
(define scalar-map `((int . ,Int) (double . ,Double) (bool . ,Bool)
                     (void . ,Void) (string . ,String)))
(define (sig-type->internal t)
  (cond [(assq t scalar-map) => cdr]
        [(and (pair? t) (symbol? (car t)))
         (cons (car t) (map sig-type->internal (cdr t)))]
        [else t]))

(define (load-binding-form! form)
  (match form
    [`(deftype ,(? symbol? name) (cpp ,(? string? c)) (header ,(? string? h)))
     (hash-set! types name (vector c h))]
    [`(defop ,(? symbol? name)
        (sig (,argts ...) ,rett)
        (cpp ,(? string? c))
        ,rest ...)
     (let ([muts (match (assq 'mutates rest) [`(mutates ,is ...) is] [_ '()])])
       (hash-set! ops name
                  (vector (map sig-type->internal argts)
                          (sig-type->internal rett)
                          c muts)))]
    [`(model ,(? symbol? name) ,lam)
     (set! models (cons (cons name lam) models))]
    [`(binding-test ,forms ...)
     (set! tests (cons forms tests))]
    [_ (eprintf "custom-binding: malformed form skipped: ~a~n"
                (if (pair? form) (car form) form))]))

(define (load-binding! [path (getenv "SCM2CPP_BINDING")])
  (when (and path (not loaded))
    (with-handlers ([(lambda (_) #t)
                     (lambda (_)
                       (eprintf "custom-binding: cannot read ~a~n" path))])
      (with-input-from-file path
        (lambda ()
          (let loop ()
            (let ([f (read)])
              (unless (eof-object? f)
                (load-binding-form! f)
                (loop))))))
      (set! loaded #t)
      (eprintf "custom-binding: ~a types, ~a ops from ~a~n"
               (hash-count types) (hash-count ops) path))))

(define (binding-type? name) (and (symbol? name) (hash-has-key? types name)))
(define (binding-type-cpp name) (vector-ref (hash-ref types name) 0))
(define (binding-type-header name) (vector-ref (hash-ref types name) 1))

(define (binding-op? name) (and (symbol? name) (hash-has-key? ops name)))
(define (binding-op-sig-args name) (vector-ref (hash-ref ops name) 0))
(define (binding-op-sig-ret name) (vector-ref (hash-ref ops name) 1))
(define (binding-op-cpp name) (vector-ref (hash-ref ops name) 2))
(define (binding-op-mutates name) (vector-ref (hash-ref ops name) 3))

;; Every header any operand type of OP mentions, for the include list.
(define (binding-op-headers name)
  (remove-duplicates
   (filter-map
    (lambda (t) (and (pair? t) (binding-type? (car t)) (binding-type-header (car t))))
    (cons (binding-op-sig-ret name) (binding-op-sig-args name)))))

(define (binding-models) models)
(define (binding-tests) (reverse tests))

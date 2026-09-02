#lang racket
;;;; --blas: the matrix products of the array algebra as BLAS calls.
;;;;
;;;; The whole-array product forms of array-macros.scm,
;;;;
;;;;   (array-set! g (matmul x (transpose x)))      g = x x^T
;;;;   (array-set! c (matmul x v))                  c = x v
;;;;   (array-dec! r (matmul (transpose x) d))      r -= x^T d   (array-inc!: +=)
;;;;   (array-set! g (matmul a (transpose b)))      g = a b^T
;;;;   (array-set! g (matmul a b))                  g = a b
;;;;   (array-dec! r (matmul (transpose d) x))      r -= d^T x   (the matrix residual)
;;;;
;;;; each expand to the loop nest that computes them cell by cell; this
;;;; pass, run on the source before that expansion (after --derive,
;;;; which writes the first three), replaces each by one call of an
;;;; operation a binding declares:
;;;;
;;;;   (blas-gram! g x p n)                 bindings/cblas-binding.scm
;;;;   (blas-gemv! c x v p n)               or bindings/cublas-binding.scm,
;;;;   (blas-gemv-t-add! r x d alpha p n)   loaded with the flag
;;;;   (blas-gemm-nt! g a b p q n)
;;;;   (blas-gemm-nn! g a b p q n)
;;;;   (blas-gemm-tn-add! r d x alpha p q n)
;;;;
;;;; so the type inference, the mutation summaries and the emitter see
;;;; an ordinary declared op (custom-binding.scm) and nothing here
;;;; matches a loop.  A form whose operation the loaded binding does
;;;; not declare is left to expand.  A vector (or matrix) operand that
;;;; is an expression rather than a name is materialised first, with
;;;; the algebra's own whole-array assignment:
;;;;   (let ((d (make-vector p 0.0)))
;;;;     (with-arrays ((d (p))) (array-set! d D))
;;;;     (blas-gemv-t-add! r x d -1.0 p n))
;;;;
;;;; Shapes come from the with-arrays declarations, read lexically:
;;;; a nested with-arrays sees the enclosing one's names (the
;;;; derivation's tables stand in such a scope and its statements mix
;;;; both).  x is row-major p x n as the flat kernels store it; the
;;;; binding's C++ does the column-major reading for BLAS.
;;;;
;;;; SCM2CPP_BLAS=cblas (--blas) or cublas (--cublas).  Under cublas
;;;; the matrix operands live on the device: the scope's body is
;;;; wrapped in (let ((dx (dmat-upload x p n))) ...) once per matrix
;;;; and the ops take dx, provided nothing in the scope writes x --
;;;; the copy is taken at scope entry.  A matrix the scope writes is
;;;; copied at each call instead, (dmat-upload x p n) in operand
;;;; position.

(require racket/runtime-path)

(provide blas-mode blas-binding-path lower-blas-forms)

(define (blas-mode)
  (let ([m (getenv "SCM2CPP_BLAS")])
    (and m (member m '("cblas" "cublas")) (string->symbol m))))

(define-runtime-path bindings-dir "bindings")

(define (blas-binding-path)
  (and (blas-mode)
       (path->string (build-path bindings-dir
                                 (format "~a-binding.scm" (blas-mode))))))

;; The heads under which a matrix is only read: as the first operand
;; of an indexing form, or as either operand of a product.
(define indexing-heads '(row array-ref vector-ref vector-length))
(define product-heads '(transpose matmul))

(define (read-only? x body)
  (let walk ([e body])
    (define (operand o) (or (eq? o x) (walk o)))
    (cond
      [(eq? e x) #f]
      [(not (list? e)) #t]
      [(null? e) #t]
      [(memq (car e) indexing-heads)
       (and (pair? (cdr e)) (operand (cadr e)) (andmap walk (cddr e)))]
      [(memq (car e) product-heads) (andmap operand (cdr e))]
      [else (andmap walk e)])))

;; FORMS -> FORMS with the products lowered, given OP? deciding which
;; operations the loaded binding declares.
(define (lower-blas-forms forms op?)
  (define cuda? (eq? (blas-mode) 'cublas))
  (define (mat? o decls)
    (and (symbol? o) (assq o decls) (= 2 (length (cadr (assq o decls))))))
  (define (dims m decls) (cadr (assq m decls)))
  (define (vec-name? o decls)
    (and (symbol? o) (assq o decls) (= 1 (length (cadr (assq o decls))))))
  ;; the column count of a matrix expression (a declared name, scale,
  ;; + - * over such), or #f
  (define (mcols m decls)
    (cond [(mat? m decls) (cadr (dims m decls))]
          [(and (pair? m) (eq? (car m) 'scale) (= (length m) 3)) (mcols (caddr m) decls)]
          [(and (pair? m) (memq (car m) '(+ - *))) (ormap (lambda (x) (mcols x decls)) (cdr m))]
          [else #f]))

  ;; outside any scope: find the scopes
  (define (walk e)
    (match e
      [`(with-arrays ,(? list? inner) ,body ...) (scope inner body '())]
      [(? pair?) (map walk e)]
      [_ e]))

  ;; one scope; DEVICE collects the (x . dx) uploads it needs (cublas)
  (define (scope inner body decls)
    (let* ([decls2 (append inner decls)]
           [device (box '())]
           [ro (lambda (x) (read-only? x body))]
           [body2 (map (lambda (s) (stmt s decls2 device ro)) body)]
           [ups (reverse (unbox device))])
      `(with-arrays ,inner
         ,@(if (null? ups)
               body2
               (list `(let ,(for/list ([u ups])
                              `(,(cdr u) (dmat-upload ,(car u)
                                                      ,(car (dims (car u) decls2))
                                                      ,(cadr (dims (car u) decls2)))))
                        ,@body2))))))

  ;; The matrix operand as the op sees it: the name, or under cublas
  ;; the device copy (registered in DEVICE, taken at scope entry), or,
  ;; for a matrix the scope writes, a copy taken at the call.
  (define (operand x decls device ro)
    (cond
      [(not cuda?) x]
      [(not (op? 'dmat-upload)) #f]
      [(assq x (unbox device)) => cdr]
      [(ro x)
       (let ([dx (gensym 'd)])
         (set-box! device (cons (cons x dx) (unbox device)))
         dx)]
      [else `(dmat-upload ,x ,(car (dims x decls)) ,(cadr (dims x decls)))]))

  ;; A vector or matrix operand: a declared name as is, else
  ;; materialised.  Returns (values name wrap) where (wrap form) binds
  ;; the name around FORM.
  (define (array-operand v shape decls)
    (if (if (= (length shape) 1) (vec-name? v decls) (mat? v decls))
        (values v (lambda (f) f))
        (let ([d (gensym 'd)])
          (values d (lambda (f)
                      `(let ((,d (make-vector ,(if (= (length shape) 1)
                                                  (car shape)
                                                  `(* ,@shape))
                                              0.0)))
                         (with-arrays ((,d ,shape)) (array-set! ,d ,v))
                         ,f))))))

  (define (stmt e decls device ro)
    (define (opnd x) (operand x decls device ro))
    (match e
      [`(array-set! ,(? symbol? y) (matmul ,(? symbol? a) (transpose ,(? symbol? b))))
       #:when (and (mat? a decls) (mat? b decls))
       (cond
         [(and (eq? a b) (op? 'blas-gram!) (opnd a))
          `(blas-gram! ,y ,(opnd a) ,(car (dims a decls)) ,(cadr (dims a decls)))]
         [(and (not (eq? a b)) (op? 'blas-gemm-nt!) (opnd a) (opnd b))
          `(blas-gemm-nt! ,y ,(opnd a) ,(opnd b)
                          ,(car (dims a decls)) ,(car (dims b decls)) ,(cadr (dims a decls)))]
         [else e])]
      [`(array-set! ,(? symbol? y) (matmul ,(? symbol? a) ,(? symbol? b)))
       #:when (and (mat? a decls) (mat? b decls))
       (if (and (op? 'blas-gemm-nn!) (opnd a) (opnd b))
           `(blas-gemm-nn! ,y ,(opnd a) ,(opnd b)
                           ,(car (dims a decls)) ,(cadr (dims b decls)) ,(cadr (dims a decls)))
           e)]
      [`(array-set! ,(? symbol? y) (matmul ,(? symbol? a) ,v))
       #:when (and (mat? a decls) (op? 'blas-gemv!) (opnd a))
       (let-values ([(d wrap) (array-operand v (list (cadr (dims a decls))) decls)])
         (wrap `(blas-gemv! ,y ,(opnd a) ,d ,(car (dims a decls)) ,(cadr (dims a decls)))))]
      [`(,(and op (or 'array-dec! 'array-inc! 'array-set!)) ,(? symbol? y)
         (matmul (transpose ,(? symbol? a)) ,v))
       #:when (and (mat? a decls) (not (mcols v decls)) (op? 'blas-gemv-t-add!) (opnd a))
       (let-values ([(d wrap) (array-operand v (list (car (dims a decls))) decls)])
         (let* ([p (car (dims a decls))] [n (cadr (dims a decls))]
                [call `(blas-gemv-t-add! ,y ,(opnd a) ,d
                                         ,(if (eq? op 'array-dec!) -1.0 1.0) ,p ,n)]
                [i (gensym 'i)])
           (wrap (if (eq? op 'array-set!)
                     `(begin (range-for (,i ,n) (array-set! ,y ,i 0.0)) ,call)
                     call))))]
      [`(,(and op (or 'array-dec! 'array-inc! 'array-set!)) ,(? symbol? y)
         (matmul (transpose ,m) ,(? symbol? b)))
       #:when (and (mat? b decls) (op? 'blas-gemm-tn-add!) (opnd b)
                   (let ([q (mcols m decls)]) q))
       (let* ([p (car (dims b decls))] [n (cadr (dims b decls))] [q (mcols m decls)])
         (let-values ([(d wrap) (array-operand m (list p q) decls)])
           (let ([call `(blas-gemm-tn-add! ,y ,d ,(opnd b)
                                           ,(if (eq? op 'array-dec!) -1.0 1.0) ,p ,q ,n)]
                 [i (gensym 'i)] [j (gensym 'j)])
             (wrap (if (eq? op 'array-set!)
                       `(begin (range-for (,i ,q) (range-for (,j ,n) (array-set! ,y ,i ,j 0.0)))
                               ,call)
                       call)))))]
      [`(with-arrays ,(? list? inner) ,body ...) (scope inner body decls)]
      [(? pair?) (map (lambda (s) (stmt s decls device ro)) e)]
      [_ e]))

  (map walk forms))

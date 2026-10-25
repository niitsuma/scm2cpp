#lang racket
;;;; --blas: the contractions of the array algebra as BLAS calls.
;;;;
;;;; The whole-array product forms of array-macros.scm,
;;;;
;;;;   (array-set! y (contract (k ..) (i ..) (a la ..) (b lb ..)))   numpy's einsum
;;;;   (array-set! y (matmul a b))  and the other matmul shapes        its two-index case
;;;;
;;;; (and array-inc!, array-dec! for += and -=) each expand to the
;;;; loop nest that computes them cell by cell; this pass, run on the
;;;; source before that expansion (after --derive, which writes the
;;;; contractions it hoists), replaces each by one call of an operation
;;;; a binding declares:
;;;;
;;;;   (blas-gemm! y a b alpha beta ta tb m n k)   bindings/cblas-binding.scm
;;;;   (blas-gemv! y a v alpha beta ta m k)        or bindings/cublas-binding.scm,
;;;;   (blas-syrk! y a alpha beta ta m k)          loaded with the flag
;;;;
;;;; so the type inference, the mutation summaries and the emitter see
;;;; an ordinary declared op (custom-binding.scm) and nothing here
;;;; matches a loop.
;;;;
;;;; A contraction is one gemm when the summed labels sit together at
;;;; the front or the back of each operand's axis list (row-major
;;;; storage makes the other axes one contiguous dimension then):
;;;; the operand whose free labels come first in y's is the left one,
;;;; stored m x k (ta = 0) or k x m (ta = 1), the other the right one,
;;;; stored k x n (tb = 0) or n x k (tb = 1).  A right operand of rank
;;;; one is a gemv; the same name on both sides with the summed labels
;;;; in the same place is a syrk (the Gram matrix).  Labels that both
;;;; operands and y carry in front, unsummed, are a batch: the slabs
;;;; below them are contiguous, and the gemm runs over them in one
;;;; call (blas-gemm-batched!: a loop of dgemm, or
;;;; cublasDgemmStridedBatched).  Summed labels in the middle of an
;;;; operand, or free labels out of y's order, are left to expand.  A matmul is desugared to the contraction it
;;;; spells and lowered the same way.
;;;;
;;;; An operand that is an expression rather than a name is
;;;; materialised first, with the algebra's own whole-array
;;;; assignment:
;;;;   (let ((d (make-vector (* p q) 0.0)))
;;;;     (with-arrays ((d (p q))) (array-set! d D))
;;;;     (blas-gemm! y x d -1.0 1.0 0 0 n q p))
;;;;
;;;; Shapes come from the with-arrays declarations, read lexically:
;;;; a nested with-arrays sees the enclosing one's names.
;;;;
;;;; SCM2CPP_BLAS=cblas (--blas) or cublas (--cublas).  Under cublas
;;;; the matrix operands live on the device: a matrix the scope only
;;;; reads is uploaded once at scope entry, (let ((dx (dmat-upload x
;;;; rows cols))) ...), one the scope writes (and every materialised
;;;; operand) is copied at the call, (dmat-upload x rows cols) in
;;;; operand position; vectors stay on the host.

(require racket/runtime-path)

(provide blas-mode blas-binding-path lower-blas-forms lower-library-calls)

(define (blas-mode)
  (let ([m (getenv "SCM2CPP_BLAS")])
    (and m (member m '("cblas" "cublas" "cuda")) (string->symbol m))))

(define-runtime-path bindings-dir "bindings")

(define (blas-binding-path)
  (and (blas-mode)
       (path->string (build-path bindings-dir
                                 (format "~a-binding.scm" (blas-mode))))))

;; Scheme functions the BLAS binding has an op for: the kernels keep
;; calling the Scheme definition (which the oracle runs, and which a
;; build without the binding translates), and under --blas the call
;; becomes the op when the loaded binding declares it -- LAPACK's
;; dsyevd for sym-eigen.scm and dgesdd for sym-svd.scm, whose
;; contracts they meet.  Each entry is
;; the name, its arity, the op, and the op's arguments from the call's.
(define library-calls
  (list (list 'sym-eigen 5 'lapack-syevd! (lambda (a v ev e m) (list a v ev m)))
        (list 'sym-eigen-top 6 'lapack-syevr-top! (lambda (a v ev e m k) (list a v ev m k)))
        (list 'sym-eigen-gen 6 'lapack-sygvd! (lambda (a b v ev e m) (list a b v ev m)))
        (list 'spd-solve 4 'lapack-posv! (lambda (a b m q) (list a b m q)))
        (list 'sym-svd 6 'lapack-gesdd! (lambda (a u s vt m n) (list a u s vt m n)))))

(define (lower-library-calls forms op?)
  (define (walk e)
    (match e
      ;; a definition's head is not a call
      [`(define (,_ . ,_) ,body ...) (list* (car e) (cadr e) (map walk body))]
      [`(,(? symbol? f) ,args ...)
       #:when (let ([r (assq f library-calls)])
                (and r (= (length args) (cadr r)) (op? (caddr r))))
       (let ([r (assq f library-calls)])
         (cons (caddr r) (apply (cadddr r) (map walk args))))]
      [(? list?) (map walk e)]
      [_ e]))
  (map walk forms))

;; The heads under which a matrix is only read: as the first operand
;; of an indexing form, or inside a product.
(define indexing-heads '(row col array-ref vector-ref vector-length))
(define product-heads '(transpose matmul))

(define (read-only? x body)
  (let walk ([e body])
    (define (operand o) (or (eq? o x) (walk o)))
    (define (leaves-read? o)         ; a pure operand expression
      (or (not (pair? o)) (andmap leaves-read? o)))
    (cond
      [(eq? e x) #f]
      [(not (list? e)) #t]
      [(null? e) #t]
      [(memq (car e) indexing-heads)
       (and (pair? (cdr e)) (operand (cadr e)) (andmap walk (cddr e)))]
      [(memq (car e) product-heads) (andmap operand (cdr e))]
      [(eq? (car e) 'contract)
       (and (= (length e) 5)
            (leaves-read? (car (list-ref e 3)))
            (leaves-read? (car (list-ref e 4))))]
      [else (andmap walk e)])))

;; FORMS -> FORMS with the products lowered, given OP? deciding which
;; operations the loaded binding declares.
(define (lower-blas-forms forms op?)
  (define cuda? (eq? (blas-mode) 'cublas))
  (define (decl-dims o decls)
    (and (symbol? o) (assq o decls) (cadr (assq o decls))))
  ;; the dims of an operand expression: a declared name, (scale c e),
  ;; + - * over such; #f otherwise
  (define (edims e decls)
    (cond [(symbol? e) (decl-dims e decls)]
          [(and (pair? e) (eq? (car e) 'scale) (= (length e) 3)) (edims (caddr e) decls)]
          [(and (pair? e) (memq (car e) '(+ - *))) (ormap (lambda (x) (edims x decls)) (cdr e))]
          [else #f]))
  (define (prod es) (cond [(null? es) 1] [(null? (cdr es)) (car es)] [else `(* ,@es)]))

  ;; ---- matmul as the contraction it spells ----
  (define (matmul->contract a b decls)
    (define (tr? o) (and (pair? o) (eq? (car o) 'transpose) (= (length o) 2)))
    (define (base o) (if (tr? o) (cadr o) o))
    (let* ([ea (base a)] [eb (base b)]
           [da (edims ea decls)] [db (edims eb decls)])
      (and da db (= 2 (length da))
           (cond
             ;; a vector on the right: y (i) = sum_k a[i,k] b[k]
             [(= 1 (length db))
              `(contract (k) (i) (,ea ,@(if (tr? a) '(k i) '(i k))) (,eb k))]
             [(= 2 (length db))
              `(contract (k) (i j) (,ea ,@(if (tr? a) '(k i) '(i k)))
                                   (,eb ,@(if (tr? b) '(j k) '(k j))))]
             [else #f]))))

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
                                                      ,(prod (decl-dims (car u) decls2)) 1)))
                        ,@body2))))))

  ;; A matrix operand (a declared name of rank two or more) as the op
  ;; sees it: the name, or under cublas the device copy -- registered
  ;; in DEVICE and taken at scope entry when the scope only reads it,
  ;; taken at the call when the scope writes it.
  (define (operand x decls device ro)
    (cond
      [(not cuda?) x]
      [(not (op? 'dmat-upload)) #f]
      [(assq x (unbox device)) => cdr]
      [(ro x)
       (let ([dx (gensym 'd)])
         (set-box! device (cons (cons x dx) (unbox device)))
         dx)]
      [else `(dmat-upload ,x ,(prod (decl-dims x decls)) 1)]))

  ;; An operand as a name: a declared name as is, else materialised
  ;; into a fresh array of its shape.  Returns (values name wrap
  ;; fresh?) where (wrap form) binds the name around FORM.
  (define (array-operand e shape decls)
    (if (symbol? e)
        (values e (lambda (f) f) #f)
        (let ([d (gensym 'd)])
          (values d (lambda (f)
                      `(let ((,d (make-vector ,(prod shape) 0.0)))
                         (with-arrays ((,d ,shape)) (array-set! ,d ,e))
                         ,f))
                  #t))))

  ;; ---- the contraction ----
  (define (lower-contract op y ks ys oa ob decls device ro)
    (define (info o)
      (match o
        [`(,e ,ls ...)
         (let ([d (edims e decls)])
           (and d (= (length d) (length ls)) (pair? ls) (list e ls d)))]
        [_ #f]))
    (define (kpos ls)                  ; where the summed labels sit
      (cond [(< (length ls) (length ks)) #f]
            [(equal? (take ls (length ks)) ks) 'front]
            [(equal? (take-right ls (length ks)) ks) 'back]
            [else #f]))
    (define (free ls) (filter (lambda (l) (not (memq l ks))) ls))
    ;; the batch: labels shared by both operands, unsummed, which must
    ;; lead both operands' axis lists and y's, in one order
    (define (batch-of A B)
      (let ([shared (filter (lambda (l) (and (memq l (cadr B)) (not (memq l ks)))) (cadr A))])
        (and (pair? shared)
             (= (length shared) (length (remove-duplicates shared)))
             (let ([nb (length shared)])
               (and (>= (length ys) nb)
                    (equal? (take (cadr A) nb) shared)
                    (equal? (take (cadr B) nb) shared)
                    (equal? (take ys nb) shared)
                    shared)))))
    (define (extents A ls)
      (for/list ([l ls]) (list-ref (caddr A) (index-of (cadr A) l))))
    (define alpha (if (eq? op 'array-dec!) -1.0 1.0))
    (define beta (if (eq? op 'array-set!) 0.0 1.0))
    ;; a matrix operand as the op takes it: a fresh (materialised) one
    ;; is copied to the device at the call under cublas
    (define (as-operand name fresh? shape)
      (if fresh?
          (if cuda? `(dmat-upload ,name ,(prod shape) 1) name)
          (operand name decls device ro)))
    (let* ([A0 (info oa)] [B0 (info ob)]
           [batch (and A0 B0 (batch-of A0 B0))]
           [nb (if batch (length batch) 0)]
           ;; below the batch labels the operands are ordinary
           [strip (lambda (X) (and X (list (car X) (drop (cadr X) nb) (drop (caddr X) nb))))]
           [A (strip A0)] [B (strip B0)]
           [ys (if batch (drop ys nb) ys)]
           [batch-count (and batch (prod (for/list ([l batch]) (list-ref (caddr A0) (index-of (cadr A0) l)))))])
      (and A B (pair? ks)
           (let ([pa (kpos (cadr A))] [pb (kpos (cadr B))]
                 [fa (free (cadr A))] [fb (free (cadr B))])
             (and pa pb (or (pair? fa) (pair? fb))
                  (let-values ([(L R pL pR fL fR)
                                (cond [(equal? ys (append fa fb)) (values A B pa pb fa fb)]
                                      [(equal? ys (append fb fa)) (values B A pb pa fb fa)]
                                      [else (values #f #f #f #f #f #f)])])
                    (and L
                         (let* ([m (prod (extents L fL))]
                                [n (prod (extents R fR))]
                                [k (prod (extents L ks))]
                                [ta (if (eq? pL 'back) 0 1)]
                                [tb (if (eq? pR 'front) 0 1)])
                           (cond
                             ;; a batch: every slab the same gemm
                             [(and batch (op? 'blas-gemm-batched!))
                              (let-values ([(l wrapl freshl) (array-operand (car L) (caddr L) decls)]
                                           [(r wrapr freshr) (array-operand (car R) (caddr R) decls)])
                                (let ([dl (as-operand l freshl (caddr L))]
                                      [dr (as-operand r freshr (caddr R))])
                                  (and dl dr
                                       (wrapl (wrapr `(blas-gemm-batched! ,y ,dl ,dr ,alpha ,beta ,ta ,tb
                                                                          ,m ,n ,k ,batch-count))))))]
                             [batch #f]
                             ;; the Gram: one name, the summed labels in one place
                             [(and (symbol? (car L)) (eq? (car L) (car R)) (eq? pL pR)
                                   (pair? fL) (pair? fR) (op? 'blas-syrk!))
                              (let ([da (operand (car L) decls device ro)])
                                (and da `(blas-syrk! ,y ,da ,alpha ,beta ,ta ,m ,k)))]
                             ;; a vector on the left and a matrix on the right -- the
                             ;; restore, r -= x' d -- is the same gemv the other way
                             ;; round: y = op(R)^T-wise, the vector on the host
                             [(and (null? fL) (= 1 (length (cadr L))) (pair? fR)
                                   (= 2 (length (cadr R))) (op? 'blas-gemv!))
                              (let-values ([(r wrapr freshr) (array-operand (car R) (caddr R) decls)]
                                           [(l wrapl freshl) (array-operand (car L) (caddr L) decls)])
                                (let ([dr (as-operand r freshr (caddr R))])
                                  (and dr
                                       (wrapr (wrapl `(blas-gemv! ,y ,dr ,l ,alpha ,beta
                                                                  ,(if (eq? pR 'front) 1 0) ,n ,k))))))]
                             ;; a vector on the right: gemv, the vector on the host
                             [(and (null? fR) (= 1 (length (cadr R))) (op? 'blas-gemv!))
                              (let-values ([(l wrapl freshl) (array-operand (car L) (caddr L) decls)]
                                           [(r wrapr freshr) (array-operand (car R) (caddr R) decls)])
                                (let ([dl (as-operand l freshl (caddr L))])
                                  (and dl
                                       (wrapl (wrapr `(blas-gemv! ,y ,dl ,r ,alpha ,beta ,ta ,m ,k))))))]
                             [(op? 'blas-gemm!)
                              (let-values ([(l wrapl freshl) (array-operand (car L) (caddr L) decls)]
                                           [(r wrapr freshr) (array-operand (car R) (caddr R) decls)])
                                (let ([dl (as-operand l freshl (caddr L))]
                                      [dr (as-operand r freshr (caddr R))])
                                  (and dl dr
                                       (wrapl (wrapr `(blas-gemm! ,y ,dl ,dr ,alpha ,beta ,ta ,tb ,m ,n ,k))))))]
                             [else #f])))))))))

  (define (stmt e decls device ro)
    (match e
      [`(,(and op (or 'array-set! 'array-inc! 'array-dec!)) ,(? symbol? y) (matmul ,a ,b))
       #:when (assq y decls)
       (let ([c (matmul->contract a b decls)])
         (if c (stmt `(,op ,y ,c) decls device ro) e))]
      [`(,(and op (or 'array-set! 'array-inc! 'array-dec!)) ,(? symbol? y)
         (contract ,(? list? ks) ,(? list? ys) ,oa ,ob))
       #:when (assq y decls)
       (or (lower-contract op y ks ys oa ob decls device ro) e)]
      ;; y *= a b, y /= a b: the product goes to a temporary of y's
      ;; shape first (array-macros.scm does the same when nothing is
      ;; lowered), and the array-set! of that temporary is then lowered
      ;; by the clauses above
      [`(,(and op (or 'array-mul! 'array-div!)) ,(? symbol? y) (,(or 'matmul 'contract) ,_ ...))
       #:when (assq y decls)
       (let* ([d (decl-dims y decls)] [tmp (gensym 'prod)])
         (stmt `(let ((,tmp (make-vector ,(prod d) 0.0)))
                  (with-arrays ((,tmp ,d))
                    (array-set! ,tmp ,(caddr e))
                    (,op ,y ,tmp)))
               decls device ro))]
      [`(with-arrays ,(? list? inner) ,body ...) (scope inner body decls)]
      [(? pair?) (map (lambda (s) (stmt s decls device ro)) e)]
      [_ e]))

  (map walk forms))

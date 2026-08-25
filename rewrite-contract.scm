#lang racket
;;;; The intermediate general form of array contraction: not the
;;;; producer-side special case where a rule contracts its own
;;;; emission, and not the full polyhedral problem either.  The
;;;; middle ground works on any user temporary that satisfies a
;;;; syntactic discipline:
;;;;
;;;;   producer    a statement whose outer loop writes exactly one
;;;;               array, every access of it at the loop's own binder
;;;;               in the first axis -- rows may read themselves, so a
;;;;               prefix within the row is fine, but a read of any
;;;;               other row refuses;
;;;;   consumers   the statements immediately after it whose outer
;;;;               loops have the same extent and read the array only
;;;;               at their own binder, never write it, and do not
;;;;               interfere -- nothing a consumer writes appears in
;;;;               the producer or in another consumer;
;;;;   closure     the array occurs nowhere else.
;;;;
;;;; Then row a is dead the moment iteration a of the consumers ends,
;;;; so the loops fuse and the first axis contracts away: one row
;;;; buffer serves every iteration, and the original array vanishes.
;;;; No dependence analysis happens; every condition is a check on
;;;; the statement text.  What this form gives up against the
;;;; polyhedral one: offsets into neighbouring rows (a rolling window
;;;; would need a modular buffer), consumers elsewhere in the
;;;; program (would need reordering legality), and non-affine index
;;;; disciplines refuse rather than approximate.

(require (only-in (file "rewrite-incremental.scm")
                  walk-collect written-vars free-symbols subst))

(provide contract-axis producer-of consumer-of)

(define (tree-map f e)
  (f (if (list? e) (map (lambda (x) (tree-map f x)) e) e)))

;; Every access of T in S sits in a recognized form with the binder in
;; the first axis; the occurrence count proves no bare or aliased use
;; hides anywhere.  Writers are allowed only when asked.
(define (aligned-accesses s T a allow-write?)
  (define sites
    (filter values
            (for/list ([x (walk-collect pair? s)])
              (match x
                [`(array-set! ,T2 ,i ,r ...)
                 #:when (eq? T2 T)
                 (and allow-write? (eq? i a) (>= (length r) 2) 1)]
                [`(array-ref ,T2 ,i ,r ...)
                 #:when (eq? T2 T)
                 (and (eq? i a) (>= (length r) 1) 1)]
                [`(row ,T2 ,i) #:when (eq? T2 T) (and (eq? i a) 1)]
                [_ #f]))))
  (and (andmap values sites)
       (= (length sites)
          (length (walk-collect (lambda (y) (eq? y T)) s)))))

;; A producer: writes exactly one array, aligned to its outer binder.
(define (producer-of s)
  (match s
    [`(range-for (,(? symbol? a) ,n) ,_ ...)
     (let ([ws (set->list (written-vars s))])
       (and (= 1 (length ws))
            (aligned-accesses s (car ws) a #t)
            (list (car ws) a n)))]
    [_ #f]))

;; A consumer of T over extent n: same-extent outer loop, aligned
;; reads, no writes of T.
(define (consumer-of s T n)
  (match s
    [`(range-for (,(? symbol? b) ,n2) ,_ ...)
     (and (equal? n n2)
          (not (set-member? (written-vars s) T))
          (aligned-accesses s T b #f)
          (memq T (walk-collect symbol? s))
          b)]
    [_ #f]))

;; Drop the first axis: accesses of T at the binder become accesses of
;; the row buffer.
(define (drop-axis e T a Tr)
  (tree-map
   (lambda (x)
     (match x
       [`(array-set! ,T2 ,i ,r ...) #:when (and (eq? T2 T) (eq? i a))
        `(array-set! ,Tr ,@r)]
       [`(array-ref ,T2 ,i ,r ...) #:when (and (eq? T2 T) (eq? i a))
        (if (= 1 (length r)) `(array-ref ,Tr ,@r) `(array-ref ,Tr ,@r))]
       [`(row ,T2 ,i) #:when (and (eq? T2 T) (eq? i a)) Tr]
       [_ x]))
   e))


;; One attempt over a statement sequence.  dims maps arrays to their
;; declared axis extents; the contracted buffer keeps every axis but
;; the first.
(define (contract-axis stmts dims)
  (define (attempt pre prod rest)
    (match-define (list T a n) (producer-of prod))
    (define-values (consumers after)
      (let gather ([cs '()] [rest rest])
        (if (and (pair? rest) (consumer-of (car rest) T n))
            (gather (cons (car rest) cs) (cdr rest))
            (values (reverse cs) rest))))
    (and (pair? consumers)
         (assq T dims)
         (> (length (cadr (assq T dims))) 1)
         ;; closure: T lives only in the producer and these consumers
         (not (memq T (walk-collect symbol? (append pre after))))
         ;; no interference through fusion
         (for/and ([c consumers])
           (set-empty? (set-intersect (written-vars c)
                                      (free-symbols prod))))
         (for/and ([c1 consumers] [i (in-naturals)])
           (for/and ([c2 consumers] [j (in-naturals)])
             (or (= i j)
                 (set-empty? (set-intersect (written-vars c1)
                                            (free-symbols c2))))))
         (let* ([Tr (gensym 'cr)]
                [rdims (cdr (cadr (assq T dims)))]
                [pbody (match prod [`(range-for ,_ ,b ...) b])]
                [fused
                 `(let ((,Tr (make-vector (* ,@rdims) 0.0)))
                    (with-arrays ((,Tr ,rdims))
                      (range-for (,a ,n)
                        (begin
                          ,@(map (lambda (x) (drop-axis x T a Tr)) pbody)
                          ,@(for/list ([c consumers])
                              (match c
                                [`(range-for (,b ,_) ,cb ...)
                                 `(begin
                                    ,@(map (lambda (x)
                                             (drop-axis (subst b a x) T a Tr))
                                           cb))]))))
                      0))])
           (append pre (list fused) after))))
  (let loop ([pre '()] [rest stmts])
    (cond [(null? rest) #f]
          [(and (producer-of (car rest))
                (attempt (reverse pre) (car rest) (cdr rest)))]
          [else (loop (cons (car rest) pre) (cdr rest))])))

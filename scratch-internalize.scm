#lang racket
;;;; The liveness pass's first consumer: make scratch parameters internal.
;;;;
;;;; A parameter the liveness pass calls scratch is written by the
;;;; function and read by nobody afterwards -- a workspace the caller
;;;; happens to be allocating. This module moves the allocation inside:
;;;; the parameter leaves the signature, every call site stops passing
;;;; it, and the function allocates the vector itself. The ABI shrinks
;;;; and the caller loses a resource it never really owned.
;;;;
;;;; The move is performed only where it is evidently sound:
;;;;
;;;;   * the pass says the parameter is scratch;
;;;;   * every call site passes a variable bound, in the caller, to a
;;;;     fresh (make-vector E ...) used for nothing but this call;
;;;;   * E can be rebuilt inside the callee: every free variable of E
;;;;     is passed to the same call at some parameter position, so the
;;;;     extent is re-expressed in the callee's own names -- and every
;;;;     call site agrees on that re-expression.
;;;;
;;;; Anything else is left alone; the transform refuses rather than
;;;; guesses.

(provide internalize-scratch)
(require (file "scm2cpp-match.scm"))

(define (walk-collect f e)
  (let loop ([e e] [acc '()])
    (let ([acc (if (f e) (cons e acc) acc)])
      (if (pair? e) (loop (cdr e) (loop (car e) acc)) acc))))

(define (subst what for e)
  (cond [(equal? e what) for]
        [(pair? e) (cons (subst what for (car e)) (subst what for (cdr e)))]
        [else e]))

(define (count-occurrences v e)
  (length (walk-collect (lambda (x) (eq? x v)) e)))

;; prog is (begin form ...); returns the transformed program, or #f when
;; nothing internalises.
(define (internalize-scratch prog fname)
  (compute-param-liveness! prog)
  (define scratch (function-scratch-params fname))
  (define forms (match prog [`(begin ,fs ...) fs] [_ (list prog)]))
  ;; a define's own header (f p1 p2 ...) is shaped like a call to f;
  ;; collect the headers so the call scans below can skip them
  (define headers
    (for/fold ([s '()]) ([f forms])
      (match f
        [`(define ,(? pair? h) ,_ ...) (cons h s)]
        [_ s])))
  (define (call? e)
    (and (pair? e) (eq? (car e) fname) (not (member e headers))))
  (define fdef
    (for/or ([f forms])
      (match f
        [`(define (,(== fname) ,ps ...) ,body ...) (list ps body)]
        [_ #f])))
  (and fdef (pair? scratch)
       (match-let ([(list params fbody) fdef])
         ;; examine each scratch index; keep those every call site frees
         (define plans        ; idx -> extent expression in callee names
           (for/fold ([acc '()])
                     ([i scratch])
             (define exts
               (for/list ([caller forms])
                 (define calls (walk-collect call? caller))
                 (for/list ([call calls])
                   (define a (and (< i (length (cdr call)))
                                  (list-ref (cdr call) i)))
                   (define binding
                     (and (symbol? a)
                          (for/or ([b (walk-collect
                                       (lambda (e)
                                         (match e
                                           [`(,(== a) (make-vector ,_ ,_ ...)) #t]
                                           [_ #f]))
                                       caller)])
                            b)))
                   (and binding
                        ;; the workspace is used for this call alone:
                        ;; its name occurs at the binding and the call
                        (= 2 (count-occurrences a caller))
                        ;; re-express the extent through this call's own
                        ;; argument list
                        (let* ([E (cadr (cadr binding))]
                               [pairs (for/list ([arg (cdr call)] [p params])
                                        (and (symbol? arg) (cons arg p)))]
                               [m (filter values pairs)]
                               [fs (walk-collect symbol? E)])
                          (and (andmap (lambda (x) (assq x m)) fs)
                               (for/fold ([e E]) ([kv m])
                                 (subst (car kv) (cdr kv) e))))))))
             (define flat (filter values (apply append exts)))
             (define total-calls
               (for/sum ([caller forms]) (length (walk-collect call? caller))))
             (if (and (pair? flat)
                      (= (length flat) total-calls)
                      (= 1 (length (remove-duplicates flat))))
                 (cons (cons i (car flat)) acc)
                 acc)))
         (and (pair? plans)
              (let* ([idxs (sort (map car plans) <)]
                     [keep? (lambda (i) (not (memq i idxs)))]
                     [new-params (for/list ([p params] [i (in-naturals)]
                                            #:when (keep? i)) p)]
                     [dropped (for/list ([p params] [i (in-naturals)]
                                         #:unless (keep? i)) (cons i p))]
                     [wrap (lambda (body)
                             `(let ,(for/list ([d dropped])
                                      `(,(cdr d) (make-vector
                                                  ,(cdr (assq (car d) plans))
                                                  0.0)))
                                ,@body))]
                     [fix-call
                      (lambda (call)
                        `(,fname ,@(for/list ([a (cdr call)] [i (in-naturals)]
                                              #:when (keep? i)) a)))]
                     [drop-binding
                      (lambda (caller call)
                        ;; remove the caller's dead workspace bindings
                        (for/fold ([e caller])
                                  ([d dropped])
                          (define a (list-ref (cdr call) (car d)))
                          (if (symbol? a)
                              (let loop ([e e])
                                (cond [(pair? e)
                                       (cons (loop (car e))
                                             (filter
                                              (lambda (b)
                                                (not (match b
                                                       [`(,(== a) (make-vector ,_ ,_ ...)) #t]
                                                       [_ #f])))
                                              (map loop (cdr e))))]
                                      [else e]))
                              e)))])
                (define new-forms
                  (for/list ([f forms])
                    (match f
                      [`(define (,(== fname) ,_ ...) ,body ...)
                       `(define (,fname ,@new-params) ,(wrap body))]
                      [_
                       (for/fold ([e f])
                                 ([call (walk-collect call? f)])
                         (subst call (fix-call call) (drop-binding e call)))])))
                `(begin ,@new-forms))))))

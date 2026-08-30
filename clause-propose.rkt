#lang racket
;;;; Ask a language model for missing inference-rule branches, and gate them.
;;;;
;;;;   racket clause-propose.rkt -c "CMD" [-o sigs.scm] kernel.scm
;;;;
;;;; The relational type system is a pile of conde clauses, one per form,
;;;; and a program using a primitive with no clause simply has no typing --
;;;; fft once spent fifty-three minutes discovering that vector-length
;;;; lacked one. This tool closes that gap the way the other proposers
;;;; work: mechanically find the application heads the relation does not
;;;; know, ask the model for their type signatures in a fixed grammar, and
;;;; hold the answer to two gates before it becomes an or-branch of the
;;;; rules (installed through extra-op-signatures, never by editing the
;;;; relation):
;;;;
;;;;   1. the kernel must type with the proposed signatures installed;
;;;;   2. a regression corpus must type to exactly what it typed before,
;;;;      so a signature cannot smuggle a typing into programs that never
;;;;      mention it.
;;;;
;;;; The model's grammar: one s-expression per line,
;;;;     (sig NAME (ARGTYPE ...) RETTYPE)
;;;; with types among num bool void string. Anything else is discarded.

(require racket/system
         (file "type-infer-rel.scm"))

(define cmd (make-parameter #f))
(define out-file (make-parameter #f))

(define kernel-file
  (command-line
   #:program "clause-propose"
   #:once-each
   [("-c" "--command") c "Command that answers a prompt on stdin" (cmd c)]
   [("-o" "--output") f "Also append accepted signatures to <f>" (out-file f)]
   #:args (kernel) kernel))

(define (read-forms path)
  (with-input-from-file path
    (lambda ()
      (let loop ([acc '()])
        (let ([f (read)])
          (if (eof-object? f) (reverse acc) (loop (cons f acc))))))))

(define forms (read-forms kernel-file))
(define defs (filter (lambda (f) (and (pair? f) (memq (car f) '(define define-macro))))
                     forms))

;; ---------------- what the relation does not know ----------------

(define known
  '(lambda if begin let let* letrec set! delay force cons car cdr
    make-vector vector-ref vector-set! vector vector-length
    + - * / remainder modulo quotient < > <= >= =
    add1 sub1 abs sqrt sin cos tan exp log atan expt exact->inexact
    zero? display newline quote define define-macro do cond else and or not
    max min list list-ref null? length cons-stream make-promise
    with-arrays range-for range-fold range-sum array-dot array-sum
    array-ref array-set! array-inc! array-dec! array-reduce row slice
    scale box sub array-gather! array-permute!))

(define (bound-names forms)
  (for/fold ([ns '()]) ([f forms])
    (match f
      [`(define (,name . ,_) . ,_) (cons name ns)]
      [`(define ,(? symbol? name) ,_) (cons name ns)]
      [_ ns])))

(define (heads e)
  (cond [(and (pair? e) (symbol? (car e)))
         (cons (car e) (append-map heads (cdr e)))]
        [(pair? e) (append-map heads e)]
        [else '()]))

;; locals bound by let/do/lambda shapes, approximately: any symbol that
;; appears as a binder; over-approximating keeps false candidates out
(define (binders e)
  (match e
    [`(let ,(? symbol? n) ,bs . ,body)
     (append (list n) (map car bs) (append-map binders body))]
    [`(,(or 'let 'let* 'letrec) ,bs . ,body)
     #:when (list? bs)
     (append (map car bs) (append-map binders (append (map cadr bs) body)))]
    [`(lambda ,ps . ,body) (append (filter symbol? ps) (append-map binders body))]
    [`(do ,bs ,_ . ,body)
     (append (map car bs) (append-map binders body))]
    [(? pair?) (append-map binders e)]
    [_ '()]))

(define unknown
  (remove-duplicates
   (for/list ([h (append-map heads defs)]
              #:unless (memq h known)
              #:unless (memq h (bound-names defs))
              #:unless (memq h (append-map binders defs)))
     h)))

;; ---------------- the question ----------------

(define (ask prompt)
  (let* ([words (string-split (cmd))]
         [exe (find-executable-path (car words))])
    (unless exe (eprintf "clause-propose: ~a not found~n" (car words)) (exit 1))
    (with-output-to-string
      (lambda ()
        (parameterize ([current-input-port (open-input-string prompt)])
          (apply system* exe (cdr words)))))))

(define question
  (string-append
   "The Scheme program below uses primitives a type checker has no rule"
   " for. For each operator listed, state its type signature as one"
   " s-expression on its own line, exactly:\n"
   "    (sig NAME (ARGTYPE ...) RETTYPE)\n"
   "with every type one of: num bool void string. If an operator's"
   " arguments or result cannot be described by those atoms, output"
   " (skip NAME) instead. No prose.\n\n"
   "Operators: " (string-join (map symbol->string unknown) " ") "\n\n"
   "The program:\n"))

;; ---------------- the gates ----------------

(define corpus
  (for/list ([f '("bench/psumfast.scm" "test-scm2cpp/fact.scm"
                  "probe/higher-order.scm" "probe/global-set.scm")]
             #:when (file-exists? f))
    (cons f (filter (lambda (x) (and (pair? x) (eq? (car x) 'define)))
                    (read-forms f)))))

(define (corpus-types sigs)
  (parameterize ([extra-op-signatures sigs])
    (for/list ([c corpus]) (infer-program (cdr c)))))

(define baseline (corpus-types '()))

(define (atomic-type? t) (memq t '(num bool void string)))
(define (well-formed? s)
  (match s
    [`(sig ,(? symbol?) (,(? atomic-type?) ...) ,(? atomic-type?)) #t]
    [_ #f]))

;; ---------------- run ----------------

(cond
  [(parameterize ([extra-op-signatures '()]) (infer-program defs))
   (eprintf "clause-propose: the kernel already types; nothing to do~n")]
  [(null? unknown)
   (eprintf "clause-propose: kernel does not type, but no unknown operator found;~n")
   (eprintf "  the gap is a form, not a primitive -- this tool cannot help~n")
   (exit 1)]
  [else
   (eprintf "clause-propose: unknown operators: ~a~n" unknown)
   (define reply (ask (string-append question (file->string kernel-file))))
   (define proposed
     (filter well-formed?
             (with-input-from-string reply
               (lambda ()
                 (let loop ([acc '()])
                   (let ([f (with-handlers ([(lambda (e) #t) (lambda (e) eof)])
                              (read))])
                     (if (eof-object? f) (reverse acc) (loop (cons f acc)))))))))
   (define sigs (for/list ([s proposed]) (cdr s)))
   (eprintf "clause-propose: model proposes: ~a~n"
            (if (null? sigs) "(nothing usable)" sigs))
   (define typed?
     (parameterize ([extra-op-signatures sigs]) (infer-program defs)))
   (define regression-ok? (equal? (corpus-types sigs) baseline))
   (cond
     [(not typed?)
      (eprintf "clause-propose: REJECTED -- kernel still does not type~n") (exit 1)]
     [(not regression-ok?)
      (eprintf "clause-propose: REJECTED -- a corpus program changed its typing~n") (exit 1)]
     [else
      (eprintf "clause-propose: accepted; kernel types, corpus unchanged~n")
      (for ([s sigs]) (printf "(sig ~a ~a ~a)~n" (car s) (cadr s) (caddr s)))
      (when (out-file)
        (call-with-output-file (out-file) #:exists 'append
          (lambda (o) (for ([s sigs]) (fprintf o "(sig ~a ~a ~a)~n"
                                               (car s) (cadr s) (caddr s))))))])])

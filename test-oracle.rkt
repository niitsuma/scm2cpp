#lang racket/base
;;;; The oracle for the regression suite: run a test program under Racket,
;;;; and compare that output with what the translated C++ printed.
;;;;
;;;;   racket test-oracle.rkt run  PROG.scm          print what Racket produces
;;;;   racket test-oracle.rkt diff RACKET.out CPP.out   compare the two
;;;;
;;;; Translating, compiling and running only shows that the pipeline still
;;;; works. Comparing against the same program's meaning in Racket is what
;;;; shows the translation still means the same thing. No expected-output
;;;; files to maintain: Scheme itself is the specification.
;;;;
;;;; `run' evaluates the program the way the translator's pre-pass reads it,
;;;; not the way #lang racket/base would:
;;;;   - define-macro is expanded here, as the pre-pass does;
;;;;   - a one-armed (if c t) is legal, and yields void when c is false;
;;;;   - force accepts a bare thunk, because a user delay macro expands to
;;;;     one, and make-promise takes a thunk and memoises it, matching
;;;;     scm2cpp.hpp rather than R7RS.
;;;;
;;;; `diff' compares token by token, so that printed numbers agree when they
;;;; denote the same value: Racket writes 2.0 and 3.00009155413138 where C++
;;;; writes 2 and 3.00009 (six significant digits by default). Tokens that
;;;; both parse as numbers agree within SCM2CPP_TOL (default 1e-5, relative);
;;;; #t and #f compare equal to 1 and 0; anything else must match exactly.

(require racket/list
         racket/string
         (only-in racket/promise [force rkt-force] promise?)
         (only-in "scm-include.rkt" read-source-forms))

;;;; ---- reading and rewriting the program ------------------------------

(define (read-forms path) (read-source-forms path))

(define (proper-list-of? f n)
  (and (list? f) (= (length f) n)))

;; (if c t) is a legal statement in the subset; racket/base demands an else.
(define (patch-one-armed-if f)
  (cond
    [(not (pair? f)) f]
    [(eq? (car f) 'quote) f]
    [(and (eq? (car f) 'if) (proper-list-of? f 3))
     (list 'if
           (patch-one-armed-if (cadr f))
           (patch-one-armed-if (caddr f))
           '(void))]
    [else (let walk ([g f])
            (cond [(pair? g) (cons (patch-one-armed-if (car g)) (walk (cdr g)))]
                  [else g]))]))

;; define-macro, expanded here the way the translator's pre-pass expands it.
(define (collect-macros forms ns)
  (define macros (make-hasheq))
  (define rest
    (for/fold ([acc '()] #:result (reverse acc)) ([f forms])
      (cond
        [(and (pair? f) (eq? (car f) 'define-macro))
         (define spec (cadr f))
         (if (symbol? spec)
             (hash-set! macros spec (eval (caddr f) ns))          ; name (lambda ...)
             (hash-set! macros (car spec)                          ; (name . args) body
                        (eval `(lambda ,(cdr spec) ,@(cddr f)) ns)))
         acc]
        [else (cons f acc)])))
  (values rest macros))

(define (expand-macros f macros)
  (cond
    [(not (pair? f)) f]
    [(eq? (car f) 'quote) f]
    [(and (symbol? (car f)) (hash-ref macros (car f) #f))
     => (lambda (proc)
          ;; the expansion may itself be a macro call, so go round again
          (expand-macros (apply proc (cdr f)) macros))]
    [else (let walk ([g f])
            (cond [(pair? g) (cons (expand-macros (car g) macros) (walk (cdr g)))]
                  [else g]))]))

;;;; ---- the shims the subset assumes -----------------------------------

(define shims
  '(begin
     ;; A user delay macro expands to a bare lambda; the pre-pass expands a
     ;; bare (delay E) to (make-promise (lambda () E)). scm2cpp.hpp's promise
     ;; memoises a thunk, so mirror that rather than R7RS make-promise.
     (define (make-promise th)
       (if (procedure? th)
           (let ([done #f] [val #f])
             (lambda ()
               (unless done (set! val (th)) (set! done #t))
               val))
           th))
     ;; A bare (delay E), which the pre-pass turns into the above. Racket's
     ;; own delay would build a promise this force also accepts, but not the
     ;; memoising thunk the header actually emits, so shadow it.
     (define-syntax-rule (delay e ...) (make-promise (lambda () e ...)))
     (define (force x)
       (cond [(procedure? x) (x)]
             [(promise? x) (rkt-force x)]
             [else x]))))

(define (run-program path)
  (define ns (make-base-namespace))
  (parameterize ([current-namespace ns])
    (namespace-require 'racket/base)
    (namespace-require 'racket/vector)
    ;; Injected rather than required, so that the program's own force may
    ;; shadow the one here without a module-level clash.
    (namespace-set-variable-value! 'rkt-force rkt-force #t ns)
    (namespace-set-variable-value! 'promise? promise? #t ns)
    (eval shims)
    ;; The built-in array/fold layer, read from the same file the
    ;; translator's pre-pass seeds from, prepended so a file's own
    ;; define-macro of the same name lands later in collect-macros and
    ;; wins. Expansion here and expansion there are the same definitions
    ;; by construction.
    (define builtin-forms
      (let ([p (build-path (let-values ([(dir _n _d)
                                         (split-path
                                          (path->complete-path
                                           (find-system-path 'run-file)))])
                             dir)
                           "array-macros.scm")])
        (if (file-exists? p) (read-forms p) '())))
    (define-values (forms macros)
      (collect-macros (append builtin-forms (read-forms path)) ns))
    (for ([f forms])
      (eval (patch-one-armed-if (expand-macros f macros))))
    (when (namespace-variable-value 'main #t (lambda () #f))
      (void (eval '(main))))))

;;;; ---- comparing the two outputs --------------------------------------

(define tol
  (let ([s (getenv "SCM2CPP_TOL")])
    (or (and s (string->number s)) 1e-5)))

(define (normalise t)
  (cond [(string=? t "#t") "1"]
        [(string=? t "#f") "0"]
        [else t]))

;; A token need not be a bare number: tfs-lasso prints beta_hat=0.000436075.
;; Split it into the literal text between numbers and the numbers themselves,
;; so the text must match exactly while the numbers only have to agree.
(define number-rx
  #px"[-+]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?(?:/[0-9]+)?")

(define (segments s)
  (let loop ([pos 0] [acc '()])
    (define m (regexp-match-positions number-rx s pos))
    (cond
      [(not m) (reverse (cons (substring s pos) acc))]
      [else
       (define start (caar m))
       (define end (cdar m))
       (loop end (list* (cons 'num (substring s start end))
                        (substring s pos start)
                        acc))])))

(define (numbers-agree? a b)
  (define x (string->number a))
  (define y (string->number b))
  (and x y (real? x) (real? y)
       (let ([x (exact->inexact x)] [y (exact->inexact y)])
         (<= (abs (- x y)) (* tol (max 1.0 (abs x) (abs y)))))))

(define (token=? a b)
  (let ([a (normalise a)] [b (normalise b)])
    (or (string=? a b)
        (let ([sa (segments a)] [sb (segments b)])
          (and (= (length sa) (length sb))
               (for/and ([u sa] [v sb])
                 (cond [(and (pair? u) (pair? v)) (numbers-agree? (cdr u) (cdr v))]
                       [(and (string? u) (string? v)) (string=? u v)]
                       [else #f])))))))

(define (lines-of path)
  (for/list ([l (in-list (string-split (file->string* path) "\n"))])
    (string-split l)))

(define (file->string* path)
  (call-with-input-file path (lambda (in) (port->string* in))))

(define (port->string* in)
  (let loop ([acc '()])
    (define l (read-line in 'any))
    (if (eof-object? l)
        (string-join (reverse acc) "\n")
        (loop (cons l acc)))))

;; Returns #f when equal, otherwise a sentence saying where they part.
(define (compare a-path b-path)
  (define a (lines-of a-path))
  (define b (lines-of b-path))
  (cond
    [(not (= (length a) (length b)))
     (format "line count ~a vs ~a" (length a) (length b))]
    [else
     (for/or ([la a] [lb b] [n (in-naturals 1)])
       (cond
         [(not (= (length la) (length lb)))
          (format "line ~a: ~a tokens vs ~a" n (length la) (length lb))]
         [else
          (for/or ([ta la] [tb lb] [k (in-naturals 1)])
            (and (not (token=? ta tb))
                 (format "line ~a token ~a: racket ~a / c++ ~a" n k ta tb)))]))]))

;;;; ---- entry point -----------------------------------------------------

(define args (current-command-line-arguments))
(when (zero? (vector-length args))
  (eprintf "usage: test-oracle.rkt run PROG.scm | diff RACKET.out CPP.out\n")
  (exit 2))

(case (vector-ref args 0)
  [("run") (run-program (vector-ref args 1))]
  [("diff")
   (define why (compare (vector-ref args 1) (vector-ref args 2)))
   (when why (printf "~a\n" why) (exit 1))]
  [else (eprintf "unknown mode: ~a\n" (vector-ref args 0)) (exit 2)])

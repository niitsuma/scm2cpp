#lang racket
;;;; Ask a language model for a whole binding -- a mapping from a kernel's
;;;; unknown operations onto an existing C++ class (std:: or boost::) --
;;;; and gate it.
;;;;
;;;;   racket binding-propose.rkt -c "CMD" [-o binding.scm] kernel.scm
;;;;
;;;; clause-propose closes a typing gap with a bare signature; this tool
;;;; closes a *meaning* gap. The kernel speaks operations (vec-push!,
;;;; vec-len) that no rule, no signature, and no header define. The model
;;;; is asked to propose, in custom-binding.scm's grammar, the complete
;;;; story: which library class the type is (deftype), how each operation
;;;; spells in C++ (defop), and what each operation means as pure Racket
;;;; (model). The proposal is held to three gates before anyone calls it
;;;; a binding:
;;;;
;;;;   1. shape: only well-formed deftype/defop/model forms survive
;;;;      parsing, and every unknown operator must receive a defop;
;;;;   2. types: the kernel must type under the relational rules with the
;;;;      proposed signatures installed (binding-signatures);
;;;;   3. meaning: the kernel itself is appended as a binding-test and
;;;;      binding-check.rkt runs it twice -- once in Racket over the
;;;;      proposed models, once compiled against the real library class --
;;;;      and the printed output must agree.
;;;;
;;;; The test is the kernel, not the model's homework: a proposal cannot
;;;; grade itself with a test written to pass. One retry, with the failed
;;;; gate quoted back as evidence.

(require racket/system
         (file "type-infer-rel.scm")
         (only-in "scm-include.rkt" read-source-forms read-source-string))

(define cmd (make-parameter #f))
(define out-file (make-parameter #f))
(define cuda-wanted (make-parameter #f))

(define kernel-file
  (command-line
   #:program "binding-propose"
   #:once-each
   [("-c" "--command") c "Command that answers a prompt on stdin" (cmd c)]
   [("-o" "--output") f "Write the accepted binding to <f>" (out-file f)]
   [("--cuda") "Gate 3 also compiles the kernel with nvcc and compares output"
               (cuda-wanted #t)]
   #:args (kernel) kernel))

(define (read-forms path) (read-source-forms path))

(define forms (read-forms kernel-file))
(define defs (filter (lambda (f) (and (pair? f) (memq (car f) '(define define-macro))))
                     forms))

;; ---------------- what the translator does not know ----------------
;; (the same extraction clause-propose uses)

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
    (unless exe (eprintf "binding-propose: ~a not found~n" (car words)) (exit 1))
    (with-output-to-string
      (lambda ()
        (parameterize ([current-input-port (open-input-string prompt)])
          (apply system* exe (cdr words)))))))

(define question
  (string-append
   "The Scheme program below uses operations over an abstract data type"
   " a translator has no rule for. Propose a binding of that type onto an"
   " existing C++ standard library or Boost class. Prefer a std::"
   " class whenever one fits; use a Boost class only when the standard"
   " library has no equivalent -- output that never mentions boost"
   " keeps the generated kernel eligible for its minimal runtime,"
   " which is what still compiles under nvcc. Output only"
   " s-expressions, one per line, no prose, in exactly this grammar:\n\n"
   "  (deftype TYPENAME (cpp \"C++ spelling with ~a per type argument\")"
   " (header \"<...>\"))\n"
   "  (defop NAME (sig (ARGTYPE ...) RETTYPE)"
   " (cpp \"C++ expression with ~a per argument\") (mutates I))\n"
   "  (model NAME (lambda (ARG ...) BODY))\n\n"
   "Scalar types are int double bool void; the bound type is written"
   " (TYPENAME double) everywhere it appears in a sig, never the bare"
   " TYPENAME. For example, over a queue type the type and two"
   " operations would be:\n"
   "  (deftype queue (cpp \"std::queue< ~a >\") (header \"<queue>\"))\n"
   "  (defop q-new (sig () (queue double)) (cpp \"std::queue< double >()\"))\n"
   "  (defop q-pop! (sig ((queue double)) double) (cpp \"~a.pop()\")"
   " (mutates 0))\n"
   "The cpp string must contain exactly one ~a per sig argument -- a"
   " zero-argument constructor spells its concrete type and contains"
   " no ~a at all.\n"
   "Give (mutates I) only on an operation that"
   " writes its I-th argument, 0-based; omit the clause entirely"
   " otherwise -- never write (mutates #f). Every"
   " operation needs a model: a pure Racket lambda over some Racket"
   " representation of the type -- a growable sequence may be a box"
   " holding a list, using box, unbox, set-box!, append, list-ref,"
   " length. The cpp format of an operation receives its arguments"
   " in order; a method call is written \"~a.name(~a)\".\n\n"
   "Operations to bind: "
   (string-join (map symbol->string unknown) " ") "\n\n"
   "The program:\n"))

;; ---------------- gate 1: shape ----------------

(define (atomic-type? t) (memq t '(int double bool void)))
(define (sig-type? t)
  (or (atomic-type? t)
      (and (list? t) (pair? t) (symbol? (car t)) (andmap atomic-type? (cdr t)))))
(define (format-slots s)
  (length (regexp-match* #rx"~a" s)))
(define (well-formed? f)
  (match f
    [`(deftype ,(? symbol?) . ,clauses)
     (and (assq 'cpp clauses) (assq 'header clauses))]
    [`(defop ,(? symbol?) . ,clauses)
     (let ([sig (assq 'sig clauses)]
           [cpp (assq 'cpp clauses)])
       (and sig (= 3 (length sig))
            (list? (cadr sig)) (andmap sig-type? (cadr sig))
            (sig-type? (caddr sig))
            cpp (string? (cadr cpp))
            ;; the cpp format is applied to the arguments, so it must
            ;; take exactly one ~a per sig argument -- a constructor of
            ;; no arguments spells its concrete type, with no slot
            (= (format-slots (cadr cpp)) (length (cadr sig)))))]
    [`(model ,(? symbol?) (lambda ,_ . ,_)) #t]
    [_ #f]))

;; format noise a model adds around the grammar is stripped, the grammar
;; itself is not repaired: a (mutates #f) clause is dropped the way prose
;; is, but a mis-typed sig still fails well-formed?
(define (scrub f)
  (match f
    [`(defop ,name . ,clauses)
     (let* ([sig (assq 'sig clauses)]
            [arity (if (and sig (list? (cadr sig))) (length (cadr sig)) 0)])
       `(defop ,name ,@(filter (lambda (c)
                                 (or (not (eq? (car c) 'mutates))
                                     (and (exact-nonnegative-integer? (cadr c))
                                          (< (cadr c) arity))))
                               clauses)))]
    [_ f]))

(define (parse-reply reply)
  (filter well-formed?
          (map scrub
          (with-input-from-string reply
            (lambda ()
              (let loop ([acc '()])
                (let ([f (with-handlers ([(lambda (e) #t) (lambda (e) eof)])
                           (read))])
                  (if (eof-object? f) (reverse acc) (loop (cons f acc))))))))))

(define (covered? proposal)
  (let ([ops (for/list ([f proposal] #:when (eq? (car f) 'defop)) (cadr f))])
    (andmap (lambda (u) (memq u ops)) unknown)))

;; The deftype cpp spelling is a format over the type arguments, so its
;; slot count must agree with how the sigs instantiate the type: a sig
;; writing (vec double) needs a deftype whose cpp has one ~a. Returns #f
;; when consistent, or the name of the first offending type.
(define (deftype-slot-mismatch proposal)
  (let ([slots (for/fold ([h (hash)]) ([f proposal] #:when (eq? (car f) 'deftype))
                 (hash-set h (cadr f) (format-slots (cadr (assq 'cpp (cddr f))))))])
    (for/or ([f proposal] #:when (eq? (car f) 'defop))
      (let ([sig (assq 'sig (cddr f))])
        (for/or ([t (cons (caddr sig) (cadr sig))] #:when (pair? t))
          (and (hash-has-key? slots (car t))
               (not (= (hash-ref slots (car t)) (length (cdr t))))
               (car t)))))))

;; ---------------- gates 2 and 3 ----------------

(define here (path->string (path-only (path->complete-path (find-system-path 'run-file)))))

(define (write-candidate proposal)
  (let ([f (make-temporary-file "scm2cpp-bindprop~a.scm")])
    (with-output-to-file f #:exists 'replace
      (lambda ()
        (displayln ";; proposed binding under test; the test is the kernel itself")
        (for ([p proposal]) (writeln p))
        (writeln (append '(binding-test) defs '((main))))))
    f))

(define (types-with? proposal)
  (let ([sigs (for/list ([f proposal] #:when (eq? (car f) 'defop))
                (let ([sig (assq 'sig (cddr f))])
                  (list (cadr f)
                        (map (lambda (t) (if (memq t '(int double)) 'num
                                             (if (pair? t) (cons (car t) (map (lambda (_) 'num) (cdr t))) t)))
                             (cadr sig))
                        (let ([r (caddr sig)])
                          (if (memq r '(int double)) 'num
                              (if (pair? r) (cons (car r) (map (lambda (_) 'num) (cdr r))) r))))))])
    (parameterize ([extra-op-signatures sigs])
      (and (infer-program defs) #t))))

(define (binding-checks? cand)
  (zero? (system/exit-code
          (format "racket ~a ~a-I ~a ~a > /dev/null 2>&1"
                  (build-path here "binding-check.rkt")
                  (if (cuda-wanted) "--cuda " "")
                  (path-only (path->complete-path kernel-file))
                  cand))))

;; ---------------- run ----------------

(when (null? unknown)
  (eprintf "binding-propose: no unknown operator in the kernel; nothing to bind~n")
  (exit 1))
(unless (memq 'main (bound-names defs))
  (eprintf "binding-propose: the kernel must define (main) that prints;~n")
  (eprintf "  it becomes the binding-test the proposal is judged by~n")
  (exit 1))

(eprintf "binding-propose: operations to bind: ~a~n" unknown)

(define (attempt extra)
  (let* ([reply (ask (string-append question (read-source-string kernel-file) extra))]
         [proposal (parse-reply reply)])
    (cond
      [(not (covered? proposal))
       (values #f (string-append
                   "not every listed operation received a well-formed defop;"
                   " remember the cpp format takes exactly one ~a per sig"
                   " argument (a zero-argument constructor has none), and the"
                   " bound type is always written (TYPENAME double)"))]
      [(deftype-slot-mismatch proposal)
       => (lambda (tn)
            (values #f (format
                        (string-append
                         "the deftype cpp spelling of ~a must contain one ~~a"
                         " per type argument, since the sigs instantiate it"
                         " as (~a double)")
                        tn tn)))]
      [(not (types-with? proposal))
       (values #f "the kernel does not type under the proposed signatures")]
      [else
       (let ([cand (write-candidate proposal)])
         (if (binding-checks? cand)
             (values (cons proposal cand) #f)
             (values #f (if (cuda-wanted)
                            (string-append
                             "the kernel must print the same output over your"
                             " models and over the real class, under g++ AND"
                             " under nvcc; a std:: class with no boost mention"
                             " is the reliable way to satisfy nvcc")
                            (string-append
                             "running the kernel over your models in Racket and over"
                             " the real C++ class printed different output")))))])))

(define-values (accepted2 why2)
  (let loop ([tries 3] [extra ""] [last-why #f])
    (if (zero? tries)
        (values #f last-why)
        (let-values ([(acc why) (attempt extra)])
          (cond
            [acc (values acc why)]
            [else
             (eprintf "binding-propose: rejected (~a)~a~n" why
                      (if (> tries 1) "; retrying with evidence" ""))
             (loop (sub1 tries)
                   (format "\n\nYour previous proposal was rejected: ~a. Propose again.\n" why)
                   why)])))))

(cond
  [accepted2
   (eprintf "binding-propose: accepted; kernel types, and its output over the~n")
   (eprintf "  models matches its output over the real class~n")
   (for ([p (car accepted2)]) (writeln p))
   (when (out-file)
     (copy-file (cdr accepted2) (out-file) #t)
     (eprintf "binding-propose: written to ~a~n" (out-file)))]
  [else
   (eprintf "binding-propose: REJECTED -- ~a~n" why2)
   (exit 1)])

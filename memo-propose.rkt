#lang racket
;;;; Ask a language model what to store so that repeated work is shared,
;;;; then hold the answer to two gates: it must give the same numbers, and
;;;; it must actually change how the cost grows.
;;;;
;;;; This is a different question from "rewrite this shape", where an
;;;; answer check alone would do. Here the model proposes a *quantity to
;;;; keep* -- a memo table, a prefix sum, a Gram matrix -- and rewrites the
;;;; program around it. Such
;;;; a change is worth making only if the work grows more slowly afterwards,
;;;; and an answer check cannot see that: a proposal can be perfectly
;;;; correct and no faster, which is the interesting failure mode. Asked for
;;;; the covariance-update form of a lasso, a local model derived it
;;;; correctly and then miscounted how many lags the precomputation needs,
;;;; O(n) instead of O(wmax). Every number it produced was right; only the
;;;; growth was wrong, and only a timing gate can tell.
;;;;
;;;; The conversation runs in stages, because that is how the derivation
;;;; actually goes: what to store, then whether the problem's structure
;;;; makes storing it affordable, then the rewritten program. Each stage
;;;; sees the previous answer.
;;;;
;;;;   racket memo-propose.rkt -c "ask-local -n 900" -o out.scm kernel.scm
;;;;
;;;; kernel.scm must define (main) and print its results, so that the two
;;;; gates have something to compare and to time. Sizes for the timing gate
;;;; come from --sizes, each being a literal in the program to vary.

(require racket/system
         (only-in "scm-include.rkt" read-source-string))

(define cmd (make-parameter #f))
(define typecheck-wanted #f)
(define out-file (make-parameter "proposed-memo.scm"))
(define size-spec (make-parameter #f))
(define tries (make-parameter 2))

(define kernel-file
  (command-line
   #:program "memo-propose"
   #:once-each
   [("-c" "--command") c "Command that answers prompts on stdin" (cmd c)]
   [("-o" "--output") f "Write the accepted program to <f>" (out-file f)]
   [("-n" "--tries") n "Attempts per stage (default 2)" (tries (string->number n))]
   ;; The relational inferencer as the first gate: a stage-3 candidate
   ;; that does not type is rejected -- with that as the evidence handed
   ;; back -- without being run. Types are the cheapest check, so they
   ;; come before execution and timing.
   [("-t" "--typecheck") "Type each candidate relationally before running it"
                         (set! typecheck-wanted #t)]
   [("-s" "--sizes") s
    "NAME=A,B,C -- vary this literal to measure how the cost grows"
    (size-spec s)]
   #:args (kernel)
   kernel))

(unless (cmd)
  (eprintf "memo-propose: -c is required~n") (exit 2))

(define source (read-source-string kernel-file))

;;;; ---------------- talking to the model ----------------

(define (ask prompt)
  (let* ([words (string-split (cmd))]
         [exe (and (pair? words) (find-executable-path (car words)))])
    (unless exe (eprintf "memo-propose: ~a not found~n" (car words)) (exit 1))
    (with-output-to-string
      (lambda ()
        (parameterize ([current-input-port (open-input-string prompt)])
          (apply system* exe (cdr words)))))))

;; The first top-level (define ...) sequence in a reply, as a program.
(define (extract-program text)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let loop ([in (open-input-string text)] [acc '()])
      (let ([f (read in)])
        (cond [(eof-object? f) (and (pair? acc) (reverse acc))]
              [(and (pair? f) (eq? (car f) 'define)) (loop in (cons f acc))]
              [else (loop in acc)])))))

;;;; ---------------- gate 1: the same numbers ----------------

(define (run-program forms)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (parameterize ([current-namespace (make-base-namespace)])
      (with-output-to-string
        (lambda () (for ([f forms]) (eval f)) (eval '(main)))))))

;;;; ---------------- gate 2: the cost grows more slowly ----------------
;;;; The named literal is substituted with each size and the program timed.
;;;; What matters is not that the proposal is faster at one size -- it may
;;;; be slower while a table is built -- but that its time grows less
;;;; steeply. The ratio between the largest and smallest size is compared.

;; The thing being varied is usually a numeric literal, so compare with
;; equal? rather than eq?: two equal numbers need not be the same object,
;; and comparing by identity silently substituted nothing at all.
(define (substitute-size forms name value)
  (let loop ([e forms])
    (cond [(equal? e name) value]
          [(pair? e) (cons (loop (car e)) (loop (cdr e)))]
          [else e])))

;; Best of three: a single run of a short program is mostly noise.
(define (time-program forms)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (parameterize ([current-namespace (make-base-namespace)])
      (for ([f forms]) (eval f))
      (for/fold ([best +inf.0]) ([_ 3])
        (let ([t0 (current-inexact-milliseconds)])
          (parameterize ([current-output-port (open-output-nowhere)])
            (eval '(main)))
          (min best (- (current-inexact-milliseconds) t0)))))))

;; Timing one program once gives a number that wanders; the decision here
;; rests on a ratio between two such numbers, which wanders twice as much.
;; The whole sweep of sizes is therefore repeated, and each size keeps its
;; own best, so a stall during one run cannot make a proposal look better
;; than it is -- which it did, admitting a rewrite that stored a value and
;; changed nothing.
(define (growth forms name sizes)
  (let ([bests (make-vector (length sizes) +inf.0)])
    (for ([round 3])
      (for ([v sizes] [i (in-naturals)])
        (let ([t (time-program (substitute-size forms name v))])
          (unless t (vector-set! bests i #f))
          (when (and t (real? (vector-ref bests i)))
            (vector-set! bests i (min (vector-ref bests i) t))))))
    (let ([ts (vector->list bests)])
      (and (andmap real? ts) ts))))

(define (parse-sizes s)
  (and s
       (match (string-split s "=")
         [(list n vs)
          (cons (or (string->number n) (string->symbol n))
                (map string->number (string-split vs ",")))]
         [_ #f])))

;;;; ---------------- the stages ----------------

(define stage1
  (string-append
   "Here is a numerical kernel in a small Scheme subset. Some quantity may"
   " be computed once and kept, so that repeated work is shared and the"
   " per-step cost stops depending on the size of the data. Say in plain"
   " prose, no code: what exactly should be stored, how is it initialised,"
   " and what recurrence keeps it correct when the loop variables change?"
   " If nothing worthwhile can be shared, say so plainly.\n\n"
   "Work it out rather than judging it at a glance. Take the quantity the"
   " inner loop computes afresh each time -- call it Q. Write down what Q"
   " becomes after the update the loop performs, by substituting the"
   " update into Q's own definition and expanding. If the result is Q's"
   " old value plus a correction, then Q can be stored and corrected"
   " instead of recomputed, and the question becomes what the correction"
   " needs. Do that expansion before answering. Note that a correction"
   " term may itself be a quantity that can be prepared once.\n\n"))

(define stage2
  (string-append
   "Storing that has a cost of its own, and the rewrite is only worth"
   " making if building it is cheaper than the work it saves. Look at how"
   " the values being combined are actually formed in this program --"
   " whether they come from a structure such as a prefix sum, a moving"
   " window, or a recurrence. Does that structure let the stored quantity"
   " be built more cheaply than the obvious way? State the cost of the"
   " obvious way and of the better way, in terms of the program's own"
   " sizes, and say precisely what is computed once. Prose, no code.\n\n"))

(define stage3
  (string-append
   "Now write the rewritten program. Same subset: define, let, do, if,"
   " cond, set!, vector-ref, vector-set!, make-vector, display, newline,"
   " arithmetic. It must define (main) and print exactly what the original"
   " prints, in the same order. Output ONLY the program as a sequence of"
   " top-level (define ...) forms, no prose, no code fences.\n\n"))

(define (converse)
  (let* ([a1 (ask (string-append stage1 source))]
         [_ (eprintf "~n--- stage 1: what to store ---~n~a~n" (string-trim a1))]
         [a2 (ask (string-append stage2 "The program:\n" source
                                 "\nYour analysis so far:\n" a1))]
         [_ (eprintf "~n--- stage 2: is it affordable ---~n~a~n" (string-trim a2))])
    (string-append stage3 "The original program:\n" source
                   "\nWhat to store:\n" a1 "\nHow to build it:\n" a2)))

;;;; ---------------- run ----------------

;; the relation loads lazily, so the flagless path never pays for it
(define infer-program/rel
  (delay (dynamic-require
          (build-path (or (current-load-relative-directory)
                          (current-directory))
                      "type-infer-rel.scm")
          'infer-program)))
(define (types? prog)
  (with-handlers ([(lambda (e) #t) (lambda (e) 'error)])
    (if ((force infer-program/rel) prog) #t #f)))

(define sizes (parse-sizes (size-spec)))
(define base (extract-program source))
(unless base
  (eprintf "memo-propose: cannot read ~a as a sequence of defines~n" kernel-file)
  (exit 1))
(define base-out (run-program base))
(unless base-out
  (eprintf "memo-propose: the original program does not run~n") (exit 1))
(eprintf "memo-propose: original prints ~s~n" base-out)
(define base-growth (and sizes (growth base (car sizes) (cdr sizes))))

(define final-prompt (converse))

(let loop ([prompt final-prompt] [try 1])
  (eprintf "~n--- stage 3: rewrite, attempt ~a/~a ---~n" try (tries))
  (let* ([reply (ask prompt)]
         [prog (extract-program reply)]
         [typed (and prog (or (not typecheck-wanted) (eq? #t (types? prog))))]
         [out (and prog typed (run-program prog))])
    (define (retry why)
      (if (>= try (tries))
          (begin (eprintf "memo-propose: gave up -- ~a~n" why) (exit 1))
          (loop (string-append final-prompt
                               "\n\nYour previous attempt was rejected: " why
                               "\nWrite a corrected program. Output ONLY the"
                               " program, no prose.")
                (add1 try))))
    (cond
      [(not prog) (retry "the reply was not a sequence of (define ...) forms")]
      [(not typed)
       (eprintf "memo-propose: candidate does not type; not executed~n")
       (retry "the program does not type-check (a vector used as a number, mismatched if branches, or an unbound name somewhere); it was rejected before being run")]
      [(not out) (retry "the program does not run")]
      [(not (equal? out base-out))
       (retry (format "it prints ~s where the original prints ~s" out base-out))]
      [else
       ;; correct; now does the cost grow more slowly?
       (define g (and sizes (growth prog (car sizes) (cdr sizes))))
       (cond
         [(not sizes)
          (eprintf "memo-propose: same output; no --sizes given, so growth was not checked~n")]
         [(not g) (retry "the program does not run at the requested sizes")]
         [else
          (let* ([rb (/ (last base-growth) (max 1e-9 (first base-growth)))]
                 [rp (/ (last g) (max 1e-9 (first g)))])
            (eprintf "memo-propose: time at sizes ~a~n" (cdr sizes))
            (eprintf "  original: ~a  (grew ~a-fold)~n"
                     (map (lambda (t) (~r t #:precision 1)) base-growth)
                     (~r rb #:precision 1))
            (eprintf "  proposed: ~a  (grew ~a-fold)~n"
                     (map (lambda (t) (~r t #:precision 1)) g)
                     (~r rp #:precision 1))
            ;; A proposal must grow markedly more slowly, not merely a
            ;; little: a third of the original's growth. Anything closer is
            ;; within what repeated measurement of the same program varies by.
            (when (>= rp (* 0.33 rb))
              (retry (format (string-append
                              "it computes the right numbers but its cost still grows"
                              " like the original: ~a-fold against ~a-fold across the"
                              " same sizes. The stored quantity is not buying anything;"
                              " reconsider how it is built, and how many times.")
                             (~r rp #:precision 1) (~r rb #:precision 1)))))])
       (call-with-output-file (out-file) #:exists 'replace
         (lambda (o) (for ([f prog]) (pretty-write f o))))
       (printf "memo-propose: accepted -> ~a~n" (out-file))
       (exit 0)])))

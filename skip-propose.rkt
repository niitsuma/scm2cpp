#lang racket
;;;; Ask a language model which null updates are worth skipping.
;;;;
;;;; The skip-null-update rule guards a loop that adds E*D to every cell
;;;; of an array with a test that D is zero.  Whether that is correct is
;;;; not a question -- the guarded loop is the unguarded one wherever it
;;;; runs, and where it does not run it would have written every cell
;;;; back to itself -- so the rule needs no gate beyond its own self-test.
;;;; Whether it is *worth* anything is a different kind of fact: it
;;;; depends on how often D is exactly zero, which the algorithm decides
;;;; and the source does not state.  A soft-thresholded coordinate step
;;;; lands on zero most of the time in a sparse fit; a gradient step never
;;;; does; a step that is the difference of two rounded quantities lands
;;;; there only by accident.  That is a judgement about the numerics of
;;;; the program, which is what a model is asked here, one site at a time.
;;;;
;;;; The division of labour is the one --llm-hints and --apply-rule
;;;; already make: the model chooses sites, the rule does the rewriting,
;;;; and nothing the model says is executed.  Where the program has a
;;;; main that prints, the rewritten program is run against the original
;;;; as well, which is the same output gate memo-propose.rkt applies.
;;;;
;;;;   racket skip-propose.rkt -c "ask-local" -o out.scm kernel.scm
;;;;   racket skip-propose.rkt --list kernel.scm          ; the sites only
;;;;   racket skip-propose.rkt --sites 0,2 -o out.scm kernel.scm
;;;;   racket skip-propose.rkt --all -o out.scm kernel.scm  ; = --apply-rule

(require racket/system
         (only-in "rewrite-search.scm" rule-sites rewrite-site))

(define cmd (make-parameter #f))
(define out-file (make-parameter "proposed-skip.scm"))
(define chosen (make-parameter #f))     ; #f: ask; 'all; or a list of numbers
(define list-only (make-parameter #f))

(define kernel-file
  (command-line
   #:program "skip-propose"
   #:once-each
   [("-c" "--command") c "Command that answers prompts on stdin" (cmd c)]
   [("-o" "--output") f "Write the rewritten program to <f>" (out-file f)]
   [("--list") "Print the candidate sites and stop" (list-only #t)]
   #:once-any
   [("--all") "Guard every site without asking" (chosen 'all)]
   [("--sites") s "Guard these sites (comma-separated numbers) without asking"
                (chosen (map string->number (string-split s ",")))]
   #:args (kernel)
   kernel))

(define forms
  (call-with-input-file kernel-file
    (lambda (in)
      (let loop ([acc '()])
        (let ([f (read in)])
          (if (eof-object? f) (reverse acc) (loop (cons f acc))))))))

(define sites (rule-sites 'skip-null-update forms))

(define (site-number s) (first s))
(define (site-loop s) (third s))
(define (site-lookup s) (fourth s))
(define (site-array s) ((site-lookup s) '?A))
(define (site-step s) ((site-lookup s) '?D))

(define (describe s)
  (format "SITE ~a: updates ~a by a multiple of D = ~s\n~a\n"
          (site-number s) (site-array s) (site-step s)
          (pretty-format (site-loop s) #:mode 'display)))

(when (null? sites)
  (printf "skip-propose: no loop in ~a has the shape a[i] op= E*D with D fixed~n"
          kernel-file)
  (exit 0))

(when (list-only)
  (for ([s sites]) (display (describe s)) (newline))
  (exit 0))

;;;; ---------------- the question ----------------

(define (ask prompt)
  (let* ([words (string-split (cmd))]
         [exe (and (pair? words) (find-executable-path (car words)))])
    (unless exe (eprintf "skip-propose: ~a not found~n" (car words)) (exit 1))
    (with-output-to-string
      (lambda ()
        (parameterize ([current-input-port (open-input-string prompt)])
          (apply system* exe (cdr words)))))))

(define question
  (string-append
   "Below is a numerical program in a small Scheme subset, followed by"
   " some of its loops. Each listed loop adds a multiple of a quantity D"
   " to every cell of an array, and D does not change while the loop"
   " runs. When D is exactly zero the loop does nothing, and a test"
   " before it would skip it. The test costs one comparison; the loop"
   " it skips costs one pass over the array. So the question is not"
   " whether skipping is safe -- it is -- but whether D is EXACTLY zero"
   " (not merely small) on a substantial share of the times the loop is"
   " reached. Decide that from how D is computed in this program:"
   " a soft threshold or a clamp or a comparison that returns an"
   " unchanged value makes exact zeros common; a difference of two"
   " floating-point results that are computed separately almost never"
   " is exactly zero; a gradient or Newton step never is.\n\n"
   "Answer with one line per site, in the form\n"
   "SITE k: yes -- reason\n"
   "or\n"
   "SITE k: no -- reason\n"
   "and nothing else.\n\n"))

(define (parse-answer text)
  (for/list ([m (regexp-match* #px"SITE\\s+(\\d+)\\s*:\\s*(yes|no)" text
                               #:match-select values)])
    (cons (string->number (second m)) (string=? (third m) "yes"))))

(define selected
  (match (chosen)
    ['all (map site-number sites)]
    [(? list? ks) ks]
    [#f
     (unless (cmd)
       (eprintf "skip-propose: -c is required unless --all or --sites is given~n")
       (exit 2))
     (let* ([prompt (string-append question
                                   "The program:\n" (pretty-format forms) "\n\n"
                                   (string-join (map describe sites) "\n"))]
            [reply (ask prompt)]
            [answers (parse-answer reply)])
       (eprintf "--- the model's answer ---~n~a~n" (string-trim reply))
       (when (null? answers)
         (eprintf "skip-propose: the reply names no site; nothing guarded~n")
         (exit 1))
       (for/list ([a answers] #:when (cdr a)) (car a)))]))

(for ([k selected])
  (unless (assv k (map (lambda (s) (cons (site-number s) s)) sites))
    (eprintf "skip-propose: no site ~a (there are ~a)~n" k (length sites))
    (exit 1)))

;;;; ---------------- apply, gate, write ----------------

;; Highest site first: guarding a site removes it from the numbering
;; (a guarded loop no longer matches) and shifts every later site down,
;; so the earlier numbers stay meaningful as long as the later ones go
;; first.
(define rewritten
  (for/fold ([e forms]) ([k (sort (remove-duplicates selected) >)])
    (rewrite-site 'skip-null-update e k)))

(define (run-program prog)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (parameterize ([current-namespace (make-base-namespace)])
      (with-output-to-string
        (lambda () (for ([f prog]) (eval f)))))))

(define (has-main? prog)
  (for/or ([f prog]) (match f [`(define (main) ,_ ...) #t] [_ #f])))

(cond
  [(null? selected)
   (printf "skip-propose: no site chosen; ~a left as it is~n" kernel-file)]
  [else
   (when (has-main? forms)
     (let ([a (run-program forms)] [b (run-program rewritten)])
       (unless (and a b (equal? a b))
         (eprintf "skip-propose: the guarded program prints ~s where the original prints ~s~n"
                  b a)
         (exit 1))
       (eprintf "skip-propose: same output as the original~n")))
   (call-with-output-file (out-file) #:exists 'replace
     (lambda (o) (for ([f rewritten]) (pretty-write f o))))
   (printf "skip-propose: guarded site~a ~a -> ~a~n"
           (if (> (length selected) 1) "s" "")
           (string-join (map number->string (sort selected <)) ", ")
           (out-file))])

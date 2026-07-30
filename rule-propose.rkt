#lang racket
;;;; Ask a language model for a rewrite rule, let the self-test judge it,
;;;; and on failure hand the evidence back for another attempt.
;;;;
;;;; This loop lives here, in an authoring tool, and not in the translator:
;;;; translation stays deterministic -- the same source and flags give the
;;;; same output -- and what the conversation produces is a rules file, a
;;;; reviewable artifact the user then passes to --rules. The model is
;;;; never trusted: every attempt goes through the same gate --rules
;;;; applies, and a failing attempt costs a diagnosis, not a wrong program.
;;;;
;;;;   racket rule-propose.rkt -o my-rules.scm "ask-local -n 800" \
;;;;     "Rewrite the loop summing squares 0^2+...+(n-1)^2 into closed form."

(require "rewrite-search.scm")

(define output-file (make-parameter "proposed-rules.scm"))
(define max-tries (make-parameter 3))

(define-values (cmd task)
  (command-line
   #:program "rule-propose"
   #:once-each
   [("-o" "--output") f "Append the accepted rule to <f>" (output-file f)]
   [("-n" "--tries") n "Give the model <n> attempts (default 3)"
                     (max-tries (string->number n))]
   #:args (cmd task)
   (values cmd task)))

(define format-spec
  (string-append
   "You write rewrite rules for a Scheme optimiser. Format, exactly:\n"
   "(rule NAME\n"
   "  (lhs PATTERN)\n"
   "  (rhs TEMPLATE)\n"
   "  (when COND ...)\n"
   "  (test FORM ... (main)))\n"
   "Metavariables begin with ? . Allowed conds: (distinct ?a ?b ...)"
   " (symbol ?x) (number ?x) (zero ?x). The test must be a complete"
   " program defining (main) that prints something, followed by (main)."
   " Output ONLY the rule s-expression, no prose.\n\n"))

(define (run-model prompt)
  (let* ([words (string-split cmd)]
         [exe (and (pair? words) (find-executable-path (car words)))])
    (unless exe
      (eprintf "rule-propose: ~a not found~n" (car words))
      (exit 1))
    (with-output-to-string
      (lambda ()
        (parameterize ([current-input-port (open-input-string prompt)])
          (apply system* exe (cdr words)))))))

;; The first (rule ...) form in the model's output, if any.
(define (extract-rule-form text)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (let loop ([in (open-input-string text)])
      (let ([f (read in)])
        (cond [(eof-object? f) #f]
              [(and (pair? f) (eq? (car f) 'rule)) f]
              [else (loop in)])))))

(define (describe-failure diag)
  (match diag
    ['(malformed)
     "Your reply was not a well-formed (rule ...) s-expression."]
    ['(no-match)
     "The lhs pattern did not match anything in your own test program; make the test contain the exact shape the lhs describes."]
    ['(test-does-not-run)
     "Your test program itself raises an error when run."]
    ['(rewritten-crashes)
     "After applying your rule to your test, the rewritten program raises an error."]
    [`(outputs-differ ,o ,r)
     (format "Your rule changes behaviour: on your own test the original prints ~s but the rewritten program prints ~s. The rhs is wrong; fix the formula."
             o r)]))

(define (attempt prompt try)
  (eprintf "rule-propose: attempt ~a/~a~n" try (max-tries))
  (let* ([reply (run-model prompt)]
         [form (extract-rule-form reply)]
         [r (and form (parse-external-rule form))]
         [diag (if r (diagnose-rule r) '(malformed))])
    (cond
      [(eq? diag 'ok)
       (with-output-to-file (output-file) #:exists 'append
         (lambda () (pretty-write form) (newline)))
       (printf "rule-propose: accepted ~a -> ~a~n" (rule-name r) (output-file))
       (exit 0)]
      [(>= try (max-tries))
       (eprintf "rule-propose: gave up after ~a attempts (last: ~a)~n"
                (max-tries) (describe-failure diag))
       (exit 1)]
      [else
       (eprintf "rule-propose: rejected: ~a~n" (describe-failure diag))
       (attempt (string-append
                 format-spec task "\n\n"
                 "Your previous attempt was:\n"
                 (if form (format "~s" form) reply)
                 "\n\nIt was rejected: " (describe-failure diag)
                 "\nReply with a corrected rule. Output ONLY the rule"
                 " s-expression, no prose.")
                (add1 try))])))

(attempt (string-append format-spec task) 1)

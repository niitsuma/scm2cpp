#lang racket
;;;; List the side-effect-free subexpressions a program computes more than
;;;; once, with what each depends on and how often it is reached, so that a
;;;; language model -- or a person -- can say which are worth storing.
;;;;
;;;; The division of labour is the point. Finding the repeats is mechanical
;;;; and can be done exactly: a subexpression with no effects is a function
;;;; of its free variables, so two occurrences of the same expression agree
;;;; whenever those variables do, and loop indices are free variables like
;;;; any other. Deciding which repeat is worth a table is not mechanical --
;;;; it depends on how the loops nest, how large the table would be, and
;;;; whether the values are reached in an order that lets them be filled in
;;;; -- and that is the judgement worth asking a model for.
;;;;
;;;; What this reports, it reports exactly. A candidate is listed only if it
;;;; has no side effects and occurs more than once. Whether the repeats
;;;; actually see the same inputs is left to the reader: the loop variables
;;;; each one depends on are printed, because those are what must agree.
;;;;
;;;;   racket repeat-scan.rkt kernel.scm            # human-readable
;;;;   racket repeat-scan.rkt -j kernel.scm         # one line per candidate
;;;;   racket repeat-scan.rkt -c "ask-local -n 800" kernel.scm   # ask a model

(require "block-equiv.scm")

(define as-lines (make-parameter #f))
(define cmd (make-parameter #f))
(define min-size (make-parameter 3))

(define kernel-file
  (command-line
   #:program "repeat-scan"
   #:once-each
   [("-j" "--lines") "One line per candidate, for piping" (as-lines #t)]
   [("-c" "--command") c "Ask this command which to memoise" (cmd c)]
   [("-m" "--min-size") m "Ignore expressions smaller than <m> nodes"
                        (min-size (string->number m))]
   #:args (kernel)
   kernel))

(define forms
  (with-input-from-file kernel-file
    (lambda ()
      (let loop ([acc '()])
        (let ([f (read)])
          (if (eof-object? f) (reverse acc) (loop (cons f acc))))))))

;;;; ---------------- walking ----------------

(define (node-count e)
  (if (pair? e) (apply + 1 (map node-count e)) 1))

;; Every subexpression, paired with the loop variables in scope where it
;; sits -- those are what decide whether two occurrences see equal inputs.
;; loops accumulates only bindings that change from one iteration to the
;; next: a do variable, or a let sitting inside one. A let outside every
;; loop -- the one wrapping a whole procedure, say -- binds a value that is
;; the same at every occurrence, and counting it as varying made the arrays
;; look like indices.
(define (subexpressions e [loops '()] [in-loop #f])
  (cond
    [(not (pair? e)) '()]
    [(eq? (car e) 'quote) '()]
    [else
     (define here (list (cons e loops)))
     (define inner
       (match e
         [`(do ((,xs ,_ ,__ ...) ...) (,test ,res ...) ,body ...)
          (let ([l2 (append xs loops)])
            (append (append-map (lambda (b) (subexpressions b l2 #t)) body)
                    (subexpressions test l2 #t)
                    (append-map (lambda (r) (subexpressions r l2 #t)) res)))]
         ;; A let binding inside a loop varies with the loop just as the
         ;; index does -- w bound to (+ j 1) is not a constant -- so it
         ;; counts among the variables whose agreement must be shown.
         [`(let ((,xs ,vs) ...) ,body ...)
          (let ([l2 (if in-loop (append xs loops) loops)])
            (append (append-map (lambda (v) (subexpressions v loops in-loop)) vs)
                    (append-map (lambda (b) (subexpressions b l2 in-loop)) body)))]
         [_ (append-map (lambda (x) (subexpressions x loops in-loop)) (cdr e))]))
     (append here inner)]))

;;;; ---------------- candidates ----------------

(define all-subs (append-map (lambda (f) (subexpressions f)) forms))

(define candidates
  (let ([tbl (make-hash)])
    (for ([p all-subs])
      (let ([e (car p)])
        (when (and (pair? e)
                   (>= (node-count e) (min-size))
                   (pure-block? e))
          (hash-update! tbl e (lambda (v) (cons (cdr p) v)) '()))))
    (sort
     (for/list ([(e sites) (in-hash tbl)] #:when (> (length sites) 1))
       (list e (length sites)
             (block-free-vars e)
             ;; bound at *every* occurrence, not at some
             (if (null? sites) '()
                 (filter (lambda (v) (andmap (lambda (s) (memq v s)) sites))
                         (remove-duplicates (apply append sites))))))
     (lambda (a b) (> (* (cadr a) (node-count (car a)))
                      (* (cadr b) (node-count (car b))))))))

;;;; ---------------- report ----------------

(define (describe c)
  (match-define (list e n deps loops) c)
  ;; loops is the union over occurrences; a variable counts as varying only
  ;; if it is bound by a loop or a let at every one of them, which is what
  ;; sites-common computes. Taking the union instead made outer arrays look
  ;; like loop variables.
  (define idx (filter (lambda (v) (memq v loops)) deps))
  (define arr (filter (lambda (v) (not (memq v loops))) deps))
  (format "~s\n    computed ~a times; depends on ~a\n    of which loop variables: ~a; other inputs: ~a"
          e n (if (null? deps) "nothing" deps)
          (if (null? idx) "none" idx)
          (if (null? arr) "none" arr)))

(cond
  [(null? candidates)
   (printf "repeat-scan: no repeated side-effect-free subexpression found~n")]
  [(as-lines)
   (for ([c candidates])
     (printf "~s\t~a\t~s\t~s~n" (car c) (cadr c) (caddr c) (cadddr c)))]
  [else
   (printf "repeat-scan: ~a repeated side-effect-free subexpression(s), most costly first~n~n"
           (length candidates))
   (for ([c candidates] [i (in-naturals 1)])
     (printf "~a. ~a~n~n" i (describe c)))])

;;;; ---------------- optionally, ask ----------------

(when (and (cmd) (pair? candidates))
  (define prompt
    (string-append
     "Below is a numerical kernel, and a list of subexpressions it computes"
     " more than once. Each is free of side effects, so it is a function of"
     " the inputs listed with it; two occurrences agree whenever those"
     " inputs agree, and the loop variables among them are what decide"
     " that.\n\n"
     "Which of these, if any, is worth computing once into a table instead"
     " of recomputing? For each one you choose, say what the table is"
     " indexed by, how large it is, and in what order it can be filled so"
     " that every entry is ready before it is read. Say plainly if a"
     " candidate is not worth it -- a value recomputed cheaply, or one whose"
     " table would be as large as the work it saves, is not.\n\n"
     "The kernel:\n" (file->string kernel-file) "\n\n"
     "The repeated subexpressions:\n"
     (apply string-append
            (for/list ([c candidates] [i (in-naturals 1)])
              (format "~a. ~a\n\n" i (describe c))))))
  (let* ([words (string-split (cmd))]
         [exe (and (pair? words) (find-executable-path (car words)))])
    (unless exe (eprintf "repeat-scan: ~a not found~n" (car words)) (exit 1))
    (printf "~n--- what the model would store ---~n")
    (define reply
      (with-output-to-string
        (lambda ()
          (parameterize ([current-input-port (open-input-string prompt)])
            (apply system* exe (cdr words))))))
    (display reply)
    (newline)))

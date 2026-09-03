#lang scribble/manual
@;;;; The Racket-level interface of the translator, with examples that
@;;;; are evaluated when this manual is built: every eval:check below
@;;;; is a test, and raco scribble fails on a mismatch, so the suite
@;;;; builds this file (doc-unit in run-tests.sh).  Command-line use
@;;;; is described in README.md; this is the manual for what the
@;;;; modules provide to a Racket program.
@;;;;
@;;;; Build by hand, from the repository root:
@;;;;   raco scribble --dest /tmp/scm2cpp-doc scribblings/scm2cpp.scrbl
@;;;; (with vendor/rkanren linked or PLTCOLLECTS=$PWD/vendor:).

@(require scribble/example
          racket/sandbox
          racket/runtime-path
          (for-label racket/base
                     racket/contract
                     "../scm-include.rkt"
                     "../scm2cpp-match.scm"))

@;; The evaluator loads the real modules by absolute path (found from
@;; this file) and runs without the sandbox's file and memory limits:
@;; the translator writes a temporary file for astyle and the
@;; relational library is not small.  Its current directory is the
@;; repository root, so the examples name files as a user would.
@(define-runtime-path repo-dir "..")
@(define (repo-file f) (path->string (simplify-path (build-path repo-dir f))))
@(define ev
   (parameterize ([sandbox-security-guard current-security-guard]
                  [sandbox-memory-limit #f]
                  [sandbox-eval-limits #f])
     (make-base-eval `(require racket/list racket/string
                               (file ,(repo-file "scm-include.rkt"))
                               (file ,(repo-file "scm2cpp-match.scm"))))))
@(ev `(current-directory ,(path->string (simplify-path repo-dir))))

@title{Scm2Cpp: the Racket interface}

Scm2Cpp translates a subset of Scheme into human-readable C++.  The
command line (@tt{racket scm2cpp-file.scm -t scm2c.typ prog.scm}) and
the subset are described in @tt{README.md}; this manual is for the
two modules a Racket program can @racket[require] directly: the
reader that splices @racket[include] forms, and the translator.

Every example here is evaluated when the manual is built, and the
build fails when a checked value differs, so the manual doubles as a
test of the interface; @tt{run-tests.sh} builds it as its
@tt{doc-unit}.  Examples whose C++ carries a numbered template
type (@tt{Unknown_typeNNNType}, a counter) are not checked by text;
they live as comments in @tt{scm2cpp-match.scm} next to its
@racket[module+ test] submodules.

@section{Reading a source program}

@defmodule[#:multi ("scm-include.rkt") #:packages ()]

A top-level @racket[(include "file.scm")] in a source program stands
for the forms of that file, relative to the file the form is written
in, as Racket's own @racket[include] does; the included file may
include others.  Every reader of a source program in the repository
(the translator, the relational gate, the oracle, the proposers, the
tests) goes through one of the two readers here, so a definition
several programs share is written once and included rather than
copied.  A file is spliced once per program: a second include of it,
direct or through another included file, contributes nothing.

@defproc[(read-source-forms [path path-string?]) (listof any/c)]{
 The forms of the program at @racket[path], with every top-level
 include replaced by the forms of the included file.  An include
 inside a definition is left as it is.

 @racket["examples/kernel-only/lasso-auto.scm"] includes
 @tt{lasso-kernel.scm} and @tt{lasso-cov.scm}, which both include
 @tt{soft-threshold.scm}; the spliced program defines each of its
 six functions once:

 @examples[#:eval ev
   (define forms (read-source-forms "examples/kernel-only/lasso-auto.scm"))
   (eval:check (map (lambda (f) (car (cadr f)))
                    (filter (lambda (f) (and (pair? f) (eq? (car f) 'define)))
                            forms))
               '(soft-threshold lasso cov-descend enet-descend mt-descend lasso-auto))
   (eval:check (ormap include-form? forms) #f)]}

@defproc[(read-source-string [path path-string?]) string?]{
 The text of the program at @racket[path] with each top-level include
 form replaced by the text of the included file, comments and layout
 kept.  This is the reader for the stages that take a string (the
 macro expander, model prompts).  The once-per-program rule holds
 here too:

 @examples[#:eval ev
   (define text (read-source-string "examples/kernel-only/lasso-auto.scm"))
   (eval:check (length (regexp-match* #rx"\\(define \\(soft-threshold" text)) 1)
   (eval:check (regexp-match? #px"(?m:^\\(include )" text) #f)]}

@defproc[(include-form? [form any/c]) boolean?]{
 Whether @racket[form] is an include form the readers honour: a
 two-element list headed by @racket['include] whose second element
 is a string.

 @examples[#:eval ev
   (eval:check (include-form? '(include "soft-threshold.scm")) #t)
   (eval:check (include-form? '(include soft-threshold)) #f)
   (eval:check (include-form? '(define (f x) x)) #f)]}

@section{Translating}

@defmodule[#:multi ("scm2cpp-match.scm") #:packages ()]

The translator proper.  It is one large module; what a caller needs
is the entry point that @tt{scm2cpp-file.scm} uses.

@defproc[(scm2cpp-match-list [source string?] [types string?])
         (list/c string? string? string?)]{
 Translates the program in @racket[source] and returns the text of
 the header (declarations followed by the definitions, since every
 function is emitted into the header), the text of the body, and an
 empty string.  @racket[types] is the text of a type file such as
 @tt{scm2c.typ}: a list of @racket[(glob ctype)] pairs, where a glob
 like @racket["*int"] gives the C type of every name ending in
 @tt{int} that inference does not fix otherwise.  The translator
 options (@tt{--derive}, @tt{--blas}, @tt{--cublas}, @tt{-I}) reach
 this function through the environment variables
 @tt{scm2cpp-file.scm} sets (@tt{SCM2CPP_DERIVE}, @tt{SCM2CPP_BLAS},
 @tt{SCM2CPP_INTEG}); a caller that wants them sets the same
 variables.

 The function prints its inference trace to the current output
 port, so a caller that wants only the C++ redirects that:

 @examples[#:eval ev
   (define (translate source types)
     (parameterize ([current-output-port (open-output-string)])
       (apply string-append (scm2cpp-match-list source types))))
   (define one (translate "(define (f x) (+ 1 x))" "((\"*int\" int) (\"main\" int))"))
   (eval:no-prompt (display one))
   (eval:check (regexp-match? #px"int *\n *f\\( *int +x *\\)" one) #t)
   (eval:check (regexp-match? #px"return \\(1\\+x\\)" one) #t)]

 A source program is given as text, not as forms, because its own
 @racket[define-macro]s are expanded first and an @racket[include]
 has to be spliced before that; a program read from a file goes
 through @racket[read-source-string]:

 @examples[#:eval ev
   (define fib (translate (read-source-string "probe/fib.scm") "()"))
   (eval:check (regexp-match? #px"std::unordered_map< *int, *int *> *fib_table" fib) #t)
   (eval:check (regexp-match? #px"fib_table\\[ *n *\\] *= *memo_result" fib) #t)
   (eval:check (regexp-match? #px"make_promise\\(" fib) #t)]}

@defproc[(scm2cpp-match-values [program any/c]) (values string? string?)]{
 The step under @racket[scm2cpp-match-list]: takes the program as a
 form (a @racket[begin] of the top-level forms, macros already
 expanded and named lets rewritten) and returns the header and body
 as two values, unindented.  A program whose literals fix every type
 needs no type file at all:

 @examples[#:eval ev
   (define-values (header body)
     (parameterize ([current-output-port (open-output-string)])
       (scm2cpp-match-values '(begin (define (f x) (set! y 10) (+ y x))))))
   (eval:check (regexp-match? #px"int *\n? *f\\( *int +x *\\)" header) #t)
   (eval:check (regexp-match? #px"y *= *10 *;" header) #t)
   (eval:check (string-trim body) "")]}

#lang racket

;;usgae 
;;racket scm2c-fileio [-t scm2c.typ]fname 


(require 2htdp/batch-io)
(require racket/cmdline)

;(require "scm2c.scm")
(require "scm2cpp-match.scm")


(define verbose-mode (make-parameter #f))
(define profiling-on (make-parameter #f))
(define optimize-level (make-parameter 0))
(define link-flags (make-parameter null))

(define type-fname (make-parameter "scm2c.typ"))
;; Parallel back ends. The selected mode is passed to the code generator
;; through the environment, which emits a directive in front of each
;; outermost for loop, or rewrites the loop entirely.
;;   omp    : #pragma omp parallel for                             (CPU cores)
;;   gpu    : #pragma omp target teams distribute parallel for     (offload)
;;   acc    : #pragma acc parallel loop                            (OpenACC)
;;   thrust : rewrite recognised loops as Thrust algorithms
 
(define file-to-compile
  (command-line
   #:program "compiler"
   #:once-each
   [("-v" "--verbose") "Compile with verbose messages"
                       (verbose-mode #t)]
   [("-p" "--profile") "Compile with profiling"
                       (profiling-on #t)]
   #:once-any
   [("-o" "--optimize-1") "Compile with optimization level 1"
                          (optimize-level 1)]
   ["--optimize-2"        (; show help on separate lines
                           "Compile with optimization level 2,"
                           "which includes all of level 1")
                          (optimize-level 2)]
   #:multi
   [("-l" "--link-flags") lf ; flag takes one argument
                          "Add a flag <lf> for the linker"
                          (link-flags (cons lf (link-flags)))]
   [("-t" "--type-file") tf ;type fname
                          "Add a type filename  <tf> "
                          ( type-fname tf)]
   [("-P" "--parallel") mode ; omp / gpu / acc / thrust
                          "Emit parallel code: omp, gpu, acc or thrust"
                          (putenv "SCM2CPP_PARALLEL" mode)]
   [("-I" "--integral-image") names ; "auto", or space-separated NAME/NAME:RANK tokens
                          "Rewrite box-sum nests over the named arrays (or: auto)"
                          (putenv "SCM2CPP_INTEG" names)]
   [("-R" "--rewrite-search") "Rewrite loop nests by rule search before translation"
                          (putenv "SCM2CPP_REWRITE" "1")]
   [("--rules") rfile     ; extra rewrite rules, self-tested before use
                          "Load extra rewrite rules from <rfile> (implies -R)"
                          (putenv "SCM2CPP_RULES" rfile)]
   [("--llm-hints") cmd    ; e.g. --llm-hints "ask-local -n 100"
                          "Run CMD with the source on stdin to propose -I hints"
                          (putenv "SCM2CPP_LLM_HINTS" cmd)]
   #:args (filename) ; expect one command-line argument: <filename>
   ; return the argument as a filename to compile
   filename))
 


;(display file-to-compile )

(define file-to-compile-base-name  (substring file-to-compile 0 (- (string-length file-to-compile) 4)))
(define cpp-fname (string-append file-to-compile-base-name ".cpp"))
(define hpp-fname (string-append file-to-compile-base-name ".hpp"))

(define base-name (last (regexp-split #rx"/" file-to-compile-base-name)))
;; A hyphen in the file name produced an illegal macro name.
(define header-flag-name
  (string-append
   (regexp-replace* #px"[^A-Za-z0-9_]" (string-upcase base-name) "_")
   "_HPP"))


;; With --llm-hints CMD, CMD is run with the program on its standard input
;; and is expected to print, on standard output, the space-separated names
;; of arrays that -I should be given -- or nothing, if it proposes none.
;; CMD is not part of Scm2Cpp; it is whatever the user points at, typically
;; a wrapper around a locally hosted model. This is entirely optional:
;; without the flag no command is run, and if CMD is missing, not found, or
;; prints nothing, the translation proceeds unhinted. The proposal is only
;; a hint -- an array it names is still rewritten only when the box-sum
;; nest is actually recognised, and the result is expected to be checked
;; by the regression suite like any other build.
(when (and (getenv "SCM2CPP_LLM_HINTS") (not (getenv "SCM2CPP_INTEG")))
  (let* ([prompt (string-append
                  "Below is a Scheme program. Some arrays are written first"
                  " and afterwards only read inside a loop nest that sums,"
                  " for every index i1,...,ik up to the array's own extent"
                  " on each axis, every element from the origin (0,...,0) to"
                  " (i1,...,ik) -- a box sum from the origin, of whatever"
                  " rank k the array has (k=1 for a running total over a"
                  " plain sequence, k=2 for a 2D image, and so on). Reply"
                  " with ONLY the space-separated names of those arrays, or"
                  " an empty reply if there are none. You may optionally"
                  " write NAME:RANK instead of NAME if you are confident of"
                  " the rank. No prose.\n\n"
                  (file->string file-to-compile))]
         [words (string-split (getenv "SCM2CPP_LLM_HINTS"))]
         [exe (and (pair? words) (find-executable-path (car words)))]
         [out (if exe
                  (with-output-to-string
                    (lambda ()
                      (parameterize ([current-input-port (open-input-string prompt)])
                        (apply system* exe (cdr words)))))
                  "")]
         [names (filter (lambda (s) (regexp-match? #px"^[a-zA-Z][a-zA-Z0-9!?*<>=+-]*(:[0-9]+)?$" s))
                        (string-split out))])
    (unless exe (eprintf "llm-hints: ~a not found; proceeding unhinted~n" (if (pair? words) (car words) (getenv "SCM2CPP_LLM_HINTS"))))
    (unless (null? names)
      (eprintf "llm-hints: ~a~n" (string-join names " "))
      (putenv "SCM2CPP_INTEG" (string-join names " ")))))

(define result-codes
  (
   ;scmcode2codelist
   scm2cpp-match-list
   (read-file file-to-compile)
   (read-file (type-fname))
   )
)

;#ifndef BOOST_MPI_HPP
;#define BOOST_MPI_HPP
;#endif // BOOST_MPI_HPP

;(display result-codes)

(write-file 
 hpp-fname 
 (string-append "
#ifndef " header-flag-name "
#define " header-flag-name "
"
(car result-codes)
"
#endif // " header-flag-name  "
"
)
)

(write-file 
 cpp-fname
 (string-append "
#include \"" base-name ".hpp\"
// #include \"scm2cpp.hpp\"
"
(cadr result-codes))
)

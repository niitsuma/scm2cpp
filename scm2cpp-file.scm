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

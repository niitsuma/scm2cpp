#lang racket

;;usgae 
;;racket scm2c-fileio [-t scm2c.typ]fname 


(require racket/cmdline)

;; read-file and write-file used to come from 2htdp/batch-io, which loads the
;; HtDP GUI stack: requiring it initialises GTK, so the translator refused to
;; start on a machine with no display -- a container, a CI runner, a server
;; over ssh -- with "Gtk initialization failed". These two are all that was
;; used of it. write-file returns the path it wrote, as the original did, so
;; the module still reports the two files it produced.
(define (read-file path) (file->string path))
(define (write-file path content)
  (display-to-file content path #:exists 'replace)
  path)

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
   [("--apply-rule") rname ; user asserts profitability; match and self-test still gate
                          "Apply the named rule wherever it matches, ignoring the cost model"
                          (putenv "SCM2CPP_FORCE_RULE" rname)]
   [("--binding") bfile   ; a user's custom C++ template binding
                          "Map declared ops onto a user C++ header per <bfile>"
                          (putenv "SCM2CPP_BINDING" bfile)]
   [("-M" "--pymodule")   "Also emit an extern C wrapper and a ctypes loader"
                          (putenv "SCM2CPP_PYMODULE" "1")]
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

;; With -M, two more artifacts: an extern "C" wrapper over every collected
;; non-template function whose signature crosses the C ABI -- scalars pass
;; through, boost::array references become element pointers -- and a Python
;; loader that checks shapes and dtypes before handing numpy arrays in.
;; Functions whose signature does not cross (unions, closures, lists) are
;; skipped with a comment, not silently.
(when (getenv "SCM2CPP_PYMODULE")
  (define (scalar-ctype? t) (member t '("int" "double" "bool" "void" "float")))
  ;; boost::array<double,14400> -> (double 14400); std::vector<double> ->
  ;; (double #f), an array whose length the caller supplies rather than the
  ;; type. Both are contiguous, so both arrive as an element pointer.
  (define (parse-array t)
    (let ([m (regexp-match #px"^boost::array<\\s*([a-z]+)\\s*,\\s*([0-9]+)\\s*>$" t)])
      (if m
          (list (cadr m) (string->number (caddr m)))
          (let ([v (regexp-match #px"^std::vector<\\s*([a-z]+)\\s*>$" t)])
            (and v (list (cadr v) #f))))))
  (define (np-dtype ct) (case ct [("double") "np.float64"] [("float") "np.float32"]
                              [("int") "np.int32"] [("bool") "np.bool_"] [else #f]))
  (define (ctypes-scalar ct) (case ct [("double") "ctypes.c_double"] [("float") "ctypes.c_float"]
                               [("int") "ctypes.c_int"] [("bool") "ctypes.c_bool"] [else #f]))
  (define entries (capi-functions))
  (define lib-name (format "lib~a.so" base-name))
  (define-values (wrappers pyfuncs skipped)
    (for/fold ([ws '()] [ps '()] [sk '()]) ([e entries])
      (let* ([fname (car e)] [ret (cadr e)] [args (caddr e)]
             [kinds (for/list ([a args])
                      (let ([ct (regexp-replace #px"^const\\s+" (string-trim (cadr a)) "")])
                        (cond [(scalar-ctype? ct) (list 'scalar (car a) ct)]
                              [(parse-array ct) => (lambda (et) (list 'array (car a) (car et) (cadr et)))]
                              [else (list 'other (car a) ct)])))])
        (cond
         [(or (not (scalar-ctype? (string-trim ret)))
              (ormap (lambda (k) (eq? (car k) 'other)) kinds))
          (values ws ps (cons fname sk))]
         [else
          (let* ([cargs (string-join
                         (for/list ([k kinds])
                           (match k
                             [`(scalar ,n ,ct) (format "~a ~a" ct n)]
                             [`(array ,n ,et ,sz)
                              (if sz (format "~a* ~a" et n)
                                  (format "~a* ~a, int ~a_len" et n n))]))
                         ", ")]
                 ;; A std::vector parameter is rebuilt from the caller's
                 ;; buffer and copied back afterwards, so a function that
                 ;; writes it still writes what the caller passed.
                 [dynamic (filter (lambda (k) (and (eq? (car k) 'array) (not (cadddr k)))) kinds)]
                 [pre (apply string-append
                             (for/list ([k dynamic])
                               (match k
                                 [`(array ,n ,et ,_)
                                  (format "  std::vector<~a> ~a_v(~a, ~a + ~a_len);\n" et n n n n)])))]
                 [post (apply string-append
                              (for/list ([k dynamic])
                                (match k
                                  [`(array ,n ,et ,_)
                                   (format "  std::copy(~a_v.begin(), ~a_v.end(), ~a);\n" n n n)])))]
                 [call (string-join
                        (for/list ([k kinds])
                          (match k
                            [`(scalar ,n ,_) n]
                            [`(array ,n ,et ,sz)
                             (if sz
                                 (format "*reinterpret_cast<boost::array<~a,~a>*>(~a)" et sz n)
                                 (format "~a_v" n))]))
                        ", ")]
                 [w (if (null? dynamic)
                        (format "extern \"C\" ~a scm2cpp_~a(~a) {\n  ~a~a(~a);\n}\n"
                                (string-trim ret) fname cargs
                                (if (equal? (string-trim ret) "void") "" "return ")
                                fname call)
                        (format "extern \"C\" ~a scm2cpp_~a(~a) {\n~a  ~a~a(~a);\n~a~a}\n"
                                (string-trim ret) fname cargs pre
                                (if (equal? (string-trim ret) "void") "" (format "~a scm2cpp_r = " (string-trim ret)))
                                fname call post
                                (if (equal? (string-trim ret) "void") "" "  return scm2cpp_r;\n")))]
                 [pyargs (string-join (map cadr kinds) ", ")]
                 [checks (apply string-append
                                (for/list ([k kinds])
                                  (match k
                                    [`(array ,n ,et ,sz)
                                     (if sz
                                         (format "    ~a = np.ascontiguousarray(~a, dtype=~a)\n    assert ~a.size == ~a, \"~a: expected ~a elements\"\n"
                                                 n n (np-dtype et) n sz n sz)
                                         (format "    ~a = np.ascontiguousarray(~a, dtype=~a)\n"
                                                 n n (np-dtype et)))]
                                    [_ ""])))]
                 [callargs (string-join
                            (for/list ([k kinds])
                              (match k
                                [`(scalar ,n ,_) n]
                                [`(array ,n ,et ,sz)
                                 (if sz
                                     (format "~a.ctypes.data_as(ctypes.POINTER(~a))" n (ctypes-scalar et))
                                     (format "~a.ctypes.data_as(ctypes.POINTER(~a)), ~a.size" n (ctypes-scalar et) n))]))
                            ", ")]
                 [argtypes (string-join
                            (for/list ([k kinds])
                              (match k
                                [`(scalar ,_ ,ct) (ctypes-scalar ct)]
                                [`(array ,_ ,et ,sz)
                                 (if sz (format "ctypes.POINTER(~a)" (ctypes-scalar et))
                                     (format "ctypes.POINTER(~a), ctypes.c_int" (ctypes-scalar et)))]))
                            ", ")]
                 [pf (format "_lib.scm2cpp_~a.restype = ~a\n_lib.scm2cpp_~a.argtypes = [~a]\ndef ~a(~a):\n~a    return _lib.scm2cpp_~a(~a)\n\n"
                             fname (if (equal? (string-trim ret) "void") "None" (ctypes-scalar (string-trim ret)))
                             fname argtypes
                             fname pyargs checks fname callargs)])
            (values (cons w ws) (cons pf ps) sk))]))))
  (write-file
   (string-append file-to-compile-base-name "_capi.cpp")
   (string-append
    "// extern \"C\" wrappers over the translated functions, for Python and\n"
    "// any other caller that speaks the C ABI. Array parameters arrive as\n"
    "// element pointers and are reinterpreted as the boost::array the\n"
    "// function expects; the caller guarantees the length.\n"
    "// Build:\n"
    "//   g++ -O2 -std=c++17 -shared -fPIC -I. -include boost/operators.hpp \\\n"
    "//       -include boost/optional.hpp -o " lib-name " " base-name "_capi.cpp\n"
    "#include \"" base-name ".hpp\"\n#include <vector>\n#include <algorithm>\n\n"
    (apply string-append (reverse wrappers))
    (if (null? skipped) ""
        (format "// not exposed (signature does not cross the C ABI): ~a\n"
                (string-join (reverse skipped) ", ")))))
  (write-file
   (string-append file-to-compile-base-name ".py")
   (string-append
    "# ctypes loader for " lib-name ", generated alongside it.\n"
    "# Arrays are numpy arrays of the declared dtype; they are made\n"
    "# contiguous on the way in and mutated in place where the translated\n"
    "# function mutates them.\n"
    "import ctypes\nimport numpy as np\nfrom pathlib import Path\n\n"
    "_lib = ctypes.CDLL(str(Path(__file__).resolve().parent / \"" lib-name "\"))\n\n"
    (apply string-append (reverse pyfuncs))))
  (eprintf "pymodule: ~a function(s) exposed~a~n"
           (length wrappers)
           (if (null? skipped) "" (format ", ~a skipped" (length skipped)))))

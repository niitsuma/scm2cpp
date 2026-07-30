#lang racket
;;;; The gate for a user binding: does the C++ header do what the models
;;;; say? Each binding-test program is run twice -- once in Racket with
;;;; every bound operation replaced by its model, and once translated to
;;;; C++ against the real header, compiled and executed -- and the printed
;;;; output compared. This is the same standard the rewrite rules are held
;;;; to, moved to where a Racket-only test cannot reach: the claim that
;;;; foo::Matrix::at means what the model means is checked by running both.
;;;;
;;;;   racket binding-check.rkt examples/custom-template/foo-binding.scm \
;;;;          -I examples/custom-template
;;;;
;;;; Exits 0 when every test agrees, 1 otherwise.

(require "custom-binding.scm")

(define header-dirs (make-parameter '()))

(define binding-file
  (command-line
   #:program "binding-check"
   #:multi
   [("-I" "--include") d "Directory holding the user's header"
                       (header-dirs (cons d (header-dirs)))]
   #:args (bfile)
   bfile))

(load-binding! binding-file)

(unless (pair? (binding-tests))
  (eprintf "binding-check: ~a declares no binding-test~n" binding-file)
  (exit 1))

;;;; ---- the model side: run the test in Racket over the models ----------

(define (run-through-models forms)
  (with-handlers ([(lambda (_) #t) (lambda (_) #f)])
    (parameterize ([current-namespace (make-base-namespace)])
      (for ([m (binding-models)])
        (eval `(define ,(car m) ,(cdr m))))
      (with-output-to-string
        (lambda () (for ([f forms]) (eval f)))))))

;;;; ---- the C++ side: translate, compile, run ---------------------------

(define here (path->string (path-only (path->complete-path (find-system-path 'run-file)))))
(define (run-through-cpp forms)
  (let* ([dir (make-temporary-file "scm2cpp-bindchk~a" 'directory)]
         [scm (build-path dir "t.scm")]
         [cpp (build-path dir "t.cpp")]
         [exe (build-path dir "t")]
         [incs (apply string-append
                      (map (lambda (d) (format " -I~a" (path->complete-path d)))
                           (cons here (header-dirs))))])
    (with-output-to-file scm
      (lambda ()
        (for ([f forms])
          ;; the trailing (main) call runs as C++ main; drop it here
          (unless (equal? f '(main)) (writeln f)))))
    (and
     (parameterize ([current-environment-variables
                     (environment-variables-copy (current-environment-variables))])
       (putenv "SCM2CPP_BINDING" (if (relative-path? binding-file)
                                     (path->string (path->complete-path binding-file))
                                     binding-file))
       (zero? (system/exit-code
               (format "cd ~a && racket ~a -t ~a t.scm > /dev/null 2>&1"
                       dir
                       (build-path here "scm2cpp-file.scm")
                       (build-path here "scm2c.typ")))))
     (zero? (system/exit-code
             (format "g++ -O2 -std=c++11 ~a -include boost/operators.hpp -include boost/optional.hpp -o ~a ~a 2> /dev/null"
                     incs exe cpp)))
     (with-output-to-string
       (lambda () (system (format "~a" exe)))))))

;;;; ---- compare ---------------------------------------------------------

(define ok #t)
(for ([forms (binding-tests)] [k (in-naturals 1)])
  (let ([mo (run-through-models forms)]
        [co (run-through-cpp forms)])
    (cond
      [(not mo)
       (printf "test ~a: the models themselves do not run~n" k) (set! ok #f)]
      [(not co)
       (printf "test ~a: translation or compilation against the header failed~n" k)
       (set! ok #f)]
      [(equal? mo co)
       (printf "test ~a: agree (~s)~n" k mo)]
      [else
       (printf "test ~a: DISAGREE: models print ~s, C++ prints ~s~n" k mo co)
       (set! ok #f)])))
(exit (if ok 0 1))

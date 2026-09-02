#lang racket/base
;;;; (include "file") at the top level of a source program stands for
;;;; the forms of that file, as Racket's include does: the path is
;;;; relative to the file the form is written in, and the included
;;;; file may include others.  Every reader of a source program --
;;;; the translator, the relational gate, the oracle, the proposers
;;;; and the tests -- goes through one of the two readers here, so a
;;;; definition shared by several programs (soft-threshold, say) is
;;;; written once and included, not copied.  A file is spliced once
;;;; per program: a second include of it, direct or through another
;;;; included file, contributes nothing, so two kernels that each
;;;; include soft-threshold.scm can themselves be included side by
;;;; side (lasso-auto.scm takes lasso-kernel.scm and lasso-cov.scm).
;;;;
;;;; read-source-forms gives the forms with the includes spliced in.
;;;; read-source-string gives the text with each include form
;;;; replaced by the included file's text, comments and layout kept,
;;;; for the readers that take a string (the macro expander, model
;;;; prompts).  Only a top-level include is honoured; one inside a
;;;; definition is left as it is and fails downstream like any other
;;;; unknown form.

(require racket/file
         racket/list
         racket/path
         racket/string)

(provide read-source-forms
         read-source-string
         include-form?)

(define (include-form? f)
  (and (list? f) (= (length f) 2)
       (eq? (car f) 'include)
       (string? (cadr f))))

(define (complete path)
  (simplify-path (path->complete-path path)))

;; the included file, relative to the file that names it
(define (resolve from rel)
  (let ([rel (string->path rel)])
    (if (absolute-path? rel)
        rel
        (build-path (or (path-only from) (current-directory)) rel))))

(define (cycle! path seen)
  (when (member path seen)
    (error 'include "~a is included from within itself" path)))

(define (read-all in)
  (let loop ([acc '()])
    (let ([f (read in)])
      (if (eof-object? f) (reverse acc) (loop (cons f acc))))))

;; SPLICED holds every file already spliced into this program, so that
;; the same file included twice is read once.
(define (read-source-forms path [seen '()] [spliced (make-hash)])
  (let ([here (complete path)])
    (cycle! here seen)
    (hash-set! spliced here #t)
    (append*
     (for/list ([f (call-with-input-file here read-all)])
       (if (include-form? f)
           (let ([inc (complete (resolve here (cadr f)))])
             (if (hash-ref spliced inc #f)
                 '()
                 (read-source-forms inc (cons here seen) spliced)))
           (list f))))))

;; the top-level forms as syntax, for their positions in the text
(define (read-all-syntax path)
  (call-with-input-file path
    (lambda (in)
      (port-count-lines! in)
      (let loop ([acc '()])
        (let ([s (read-syntax path in)])
          (if (eof-object? s) (reverse acc) (loop (cons s acc))))))))

(define (read-source-string path [seen '()] [spliced (make-hash)])
  (let* ([here (complete path)]
         [text (file->string here)])
    (cycle! here seen)
    (hash-set! spliced here #t)
    (let loop ([stxs (read-all-syntax here)] [at 0] [out '()])
      (cond
        [(null? stxs)
         (string-append* (reverse (cons (substring text at) out)))]
        [else
         (let* ([s (car stxs)]
                [f (syntax->datum s)])
           (if (include-form? f)
               (let ([start (sub1 (syntax-position s))]
                     [end (+ (sub1 (syntax-position s)) (syntax-span s))]
                     [inc (complete (resolve here (cadr f)))])
                 (loop (cdr stxs) end
                       (list* (if (hash-ref spliced inc #f)
                                  ""
                                  (read-source-string inc (cons here seen) spliced))
                              (substring text at start)
                              out)))
               (loop (cdr stxs) at out)))]))))

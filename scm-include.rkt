#lang racket/base
;;;; (include "file") at the top level of a source program stands for
;;;; the forms of that file, as Racket's include does: the path is
;;;; relative to the file the form is written in, and the included
;;;; file may include others.  Every reader of a source program --
;;;; the translator, the relational gate, the oracle, the proposers
;;;; and the tests -- goes through one of the two readers here, so a
;;;; definition shared by several programs (soft-threshold, say) is
;;;; written once and included, not copied.
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

(define (read-source-forms path [seen '()])
  (let ([here (complete path)])
    (cycle! here seen)
    (append*
     (for/list ([f (call-with-input-file here read-all)])
       (if (include-form? f)
           (read-source-forms (resolve here (cadr f)) (cons here seen))
           (list f))))))

;; the top-level forms as syntax, for their positions in the text
(define (read-all-syntax path)
  (call-with-input-file path
    (lambda (in)
      (port-count-lines! in)
      (let loop ([acc '()])
        (let ([s (read-syntax path in)])
          (if (eof-object? s) (reverse acc) (loop (cons s acc))))))))

(define (read-source-string path [seen '()])
  (let* ([here (complete path)]
         [text (file->string here)])
    (cycle! here seen)
    (let loop ([stxs (read-all-syntax here)] [at 0] [out '()])
      (cond
        [(null? stxs)
         (string-append* (reverse (cons (substring text at) out)))]
        [else
         (let* ([s (car stxs)]
                [f (syntax->datum s)])
           (if (include-form? f)
               (let ([start (sub1 (syntax-position s))]
                     [end (+ (sub1 (syntax-position s)) (syntax-span s))])
                 (loop (cdr stxs) end
                       (list* (read-source-string (resolve here (cadr f)) (cons here seen))
                              (substring text at start)
                              out)))
               (loop (cdr stxs) at out)))]))))

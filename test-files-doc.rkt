#lang racket
;;;; FILES.md against the tree: the inventory's `requires` column must
;;;; be what the modules actually require, and every module must be in
;;;; the inventory.
;;;;
;;;;   racket test-files-doc.rkt        exit 0 when FILES.md and FILES.ja.md agree with the tree
;;;;
;;;; A module is a .scm or .rkt file at the top of the tree or under
;;;; bindings/ (vendor/ is upstream and not inventoried).  Its actual
;;;; dependencies are the (file "x.scm") and "x.rkt" references inside
;;;; its require, load and include forms.  Its documented dependencies
;;;; are the backticked names in the third cell of its row -- the row
;;;; whose first cell begins with the module's path or file name.  The
;;;; two sets, compared by file name without extension, must be equal;
;;;; names in the cell that are not modules of the tree (rkanren, a
;;;; PLaneT package) are commentary and ignored.  A module without a
;;;; row, or a row whose first cell names a module file that does not
;;;; exist, fails too, so a rename cannot leave the inventory behind.

(define here (path-only (path->complete-path (find-system-path 'run-file))))
(define (in-tree p) (build-path here p))

;; ---- the tree ----

;; Only what git tracks, where git is: a working copy may hold untracked
;; scratch modules that are not part of the tree the inventory describes.
(define tracked
  (let ([git (find-executable-path "git")])
    (and git
         (parameterize ([current-directory here])
           (let ([out (with-output-to-string
                        (lambda () (system* git "ls-files" "-z" "--" "." "bindings")))])
             (and (non-empty-string? out)
                  (list->set (string-split out "\0"))))))))
(define (tracked? p) (or (not tracked) (set-member? tracked p)))

(define (module-files)
  (filter tracked?
   (append
    (for/list ([f (directory-list here)]
               #:when (regexp-match? #rx"[.](scm|rkt)$" (path->string f)))
      (path->string f))
    (for/list ([f (directory-list (in-tree "bindings"))]
               #:when (regexp-match? #rx"[.]scm$" (path->string f)))
      (string-append "bindings/" (path->string f))))))

(define (basename p)
  (regexp-replace #rx"[.](scm|rkt)$" (last (string-split p "/")) ""))

;; the forms of a module after its #lang line
(define (module-forms p)
  (with-handlers ([exn:fail? (lambda (e) '())])
    (call-with-input-file (in-tree p)
      (lambda (in)
        (read-line in)
        (let loop ([acc '()])
          (define x (with-handlers ([exn:fail? (lambda (e) eof)]) (read in)))
          (if (eof-object? x) (reverse acc) (loop (cons x acc))))))))

(define (file-refs e)
  (cond [(and (pair? e) (eq? (car e) 'file) (pair? (cdr e)) (string? (cadr e)))
         (list (cadr e))]
        ;; a PLaneT package names a file that is not in the tree
        [(and (pair? e) (eq? (car e) 'planet)) '()]
        [(string? e) (if (regexp-match? #rx"[.](scm|rkt)$" e) (list e) '())]
        [(pair? e) (append (file-refs (car e)) (file-refs (cdr e)))]
        [else '()]))

(define (require-refs e)
  (cond [(and (pair? e) (memq (car e) '(require load include))) (file-refs (cdr e))]
        [(pair? e) (append (require-refs (car e)) (require-refs (cdr e)))]
        [else '()]))

(define (actual-requires p)
  (list->set (map basename (remove-duplicates
                            (append-map require-refs (module-forms p))))))

;; ---- the document ----

(define (backticked s)
  (map cadr (regexp-match* #rx"`([^`]+)`" s #:match-select values)))

;; (path . requires-cell) for every table row whose first cell starts
;; with a backticked name
(define (doc-rows doc)
  (for/list ([line (file->lines (in-tree doc))]
             #:when (regexp-match? #rx"^[|] *`" line))
    (define cells (map string-trim (string-split line "|" #:trim? #t)))
    (define first-name (car (backticked (car cells))))
    (cons first-name (if (>= (length cells) 3) (caddr cells) #f))))

(define (check doc modules)
  (define failures '())
  (define (fail! fmt . args) (set! failures (cons (apply format fmt args) failures)))
  (define rows (doc-rows doc))
  (define by-name (for/hash ([r rows]) (values (car r) (cdr r))))
  (define names (list->set (map basename modules)))
  ;; a row that names a module-looking file which the tree does not have
  (for ([r rows])
    (define n (car r))
    (when (and (regexp-match? #rx"[.](scm|rkt)$" n)
               (not (regexp-match? #rx"/" (regexp-replace #rx"^bindings/" n "")))
               (not (member n modules))
               (not (member (string-append "bindings/" n) modules)))
      (fail! "~a: row for `~a`, which is not a module of the tree" doc n)))
  (for ([m modules])
    (define cell (or (hash-ref by-name m #f)
                     (hash-ref by-name (last (string-split m "/")) #f)))
    (cond
      [(not cell) (fail! "~a: no row for ~a" doc m)]
      [else
       (define documented
         (for/set ([t (backticked cell)]
                   #:when (set-member? names (basename t)))
           (basename t)))
       (define actual (actual-requires m))
       (define missing (set-subtract actual documented))
       (define extra (set-subtract documented actual))
       (unless (set-empty? missing)
         (fail! "~a: ~a requires ~a, not in its row" doc m
                (sort (set->list missing) string<?)))
       (unless (set-empty? extra)
         (fail! "~a: ~a's row lists ~a, which it does not require" doc m
                (sort (set->list extra) string<?)))]))
  (reverse failures))

(define modules (module-files))
(define failures (append (check "FILES.md" modules) (check "FILES.ja.md" modules)))
(for ([f failures]) (displayln f))
(if (null? failures)
    (printf "files-doc: ~a modules, both inventories agree with the tree\n"
            (length modules))
    (begin (printf "files-doc: ~a mismatch(es)\n" (length failures)) (exit 1)))

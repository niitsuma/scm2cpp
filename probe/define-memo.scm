;; (define-memo tab (f x) s ... e): f consults tab before running s ...
;; and computing e, and records e under x afterwards.  The statements
;; stay in statement position: a (begin ...) bound by let would have
;; to become an expression.  Ordinary define-macro source, taken by
;; include (probe/hash-memo.scm, probe/fib.scm).
(define-macro (define-memo table head . body)
  (let ((arg (cadr head))
        (stmts (reverse (cdr (reverse body))))
        (last (car (reverse body))))
    `(define ,head
       (if (hash-has-key? ,table ,arg)
           (hash-ref ,table ,arg)
           (begin
             ,@stmts
             (let ((memo-result ,last))
               (hash-set! ,table ,arg memo-result)
               memo-result))))))

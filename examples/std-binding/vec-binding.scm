;; The binding binding-propose accepted from a locally hosted open-weights
;; model, verbatim: vecdemo.scm typed and ran identically over these models
;; and over the real std::vector.
(deftype vec (cpp "std::vector< ~a >") (header "<vector>"))
(defop vec-new (sig () (vec double)) (cpp "std::vector< double >()"))
(defop vec-push! (sig ((vec double) double) void) (cpp "~a.push_back(~a)") (mutates 0))
(defop vec-ref (sig ((vec double) int) double) (cpp "~a[~a]"))
(defop vec-len (sig ((vec double)) int) (cpp "~a.size()"))
(model vec-new (lambda () (box (quote ()))))
(model vec-push! (lambda (v val) (set-box! v (append (unbox v) (list val)))))
(model vec-ref (lambda (v i) (list-ref (unbox v) i)))
(model vec-len (lambda (v) (length (unbox v))))
(binding-test (define (fill-squares v n) (do ((i 0 (+ i 1))) ((= i n)) (vec-push! v (+ 0.5 (* 1.0 (* i i))))) 0) (define (main) (let ((v (vec-new))) (fill-squares v 5) (display (vec-ref v 3)) (newline) (display (vec-len v)) (newline) 0)) (main))

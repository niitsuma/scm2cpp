#lang racket
;;;; The relational inferencer, checked in both directions.
;;;;
;;;; Forwards it must agree with what algorithm W would say, including the
;;;; int-against-double decision the C++ needs. Backwards it must produce
;;;; terms of a demanded type, which is the direction that exists for the
;;;; proposer tools and which algorithm W does not have. And a stream must
;;;; come out with a type at all: that is what the recursive occurs check in
;;;; vendor/mk-recursive is there for.

(require (file "type-infer-rel.scm"))

(define failures 0)
(define (check label got want)
  (unless (equal? got want)
    (set! failures (add1 failures))
    (printf "FAIL ~a\n  got  ~s\n  want ~s\n" label got want)))
(define (check-pred label got ok?)
  (unless (ok? got)
    (set! failures (add1 failures))
    (printf "FAIL ~a\n  got  ~s\n" label got)))

;; ---- forwards: the base types, and int against double ----
(check "int literal"    (infer-type 3) 'int)
(check "double literal" (infer-type 3.5) 'double)
(check "bool literal"   (infer-type #t) 'bool)
(check "int + int"      (infer-type '(+ 1 2)) 'int)
(check "int + double"   (infer-type '(+ 1 2.5)) 'double)
(check "double + int"   (infer-type '(+ 1.5 2)) 'double)
(check "division"       (infer-type '(/ 1 2)) 'double)
(check "comparison"     (infer-type '(< 1 2)) 'bool)
(check "sqrt"           (infer-type '(sqrt 2)) 'double)

;; ---- functions ----
(check "one parameter"  (infer-type '(lambda (x) (+ x 1))) '(-> (int) int))
(check "two parameters" (infer-type '(lambda (x y) (< x y))) '(-> (int int) bool))
(check "application"    (infer-type '((lambda (x) (+ x 1)) 2)) 'int)
(check "double flows"   (infer-type '((lambda (x) (+ x 1)) 2.5)) 'double)

;; ---- let, and its polymorphism ----
(check "let"            (infer-type '(let ((x 3)) (+ x 1))) 'int)
(check "let-polymorphism"
       (infer-type '(let ((f (lambda (x) x))) (cons (f 1) (f #t))))
       '(pair int bool))

;; ---- the shapes the translator actually meets ----
(check "if"             (infer-type '(if (< 1 2) 3 4)) 'int)
(check "begin"          (infer-type '(begin (newline) 3)) 'int)
(check "named let"      (infer-type '(let loop ((i 0)) (if (< i 10) (loop (+ i 1)) i))) 'int)
(check "make-vector"    (infer-type '(make-vector 3 0.0)) '(vec double))
(check "vector-ref"     (infer-type '(vector-ref (make-vector 3 0.0) 1)) 'double)
(check "vector-set!"    (infer-type '(vector-set! (make-vector 3 0) 1 2)) 'void)
(check "a loop over a vector"
       (infer-type
        '(let ((v (make-vector 10 0.0)))
           (let loop ((i 1))
             (if (< i 10)
                 (begin (vector-set! v i (+ (vector-ref v (- i 1)) (vector-ref v i)))
                        (loop (+ i 1)))
                 v))))
       '(vec double))

;; ---- a type that contains itself ----
;; Stock miniKanren refuses this one: the occurs check sees the stream
;; inside its own type. Here it comes back as (==> T (pair int (promise T))).
(define stream-expr '(let ints ((n 0)) (cons n (delay (ints (+ n 1))))))
(check-pred "a stream has a type" (infer-type stream-expr) values)
(check "the head of a stream" (infer-type `(car ,stream-expr)) 'int)
(check-pred "the tail is the same type again"
            (infer-type `(force (cdr ,stream-expr)))
            (lambda (t) (and (pair? t) (eq? (car t) '==>))))

;; ---- ordinary type errors are still errors ----
(check "bool in arithmetic" (infer-type '(+ 1 #t)) #f)
(check "bool as a vector"   (infer-type '(vector-ref #t 0)) #f)

;; ---- backwards ----
(let ([es (inhabitants '(-> (int) int) 3)])
  (check-pred "terms of int -> int" es (lambda (l) (= 3 (length l))))
  (check-pred "and they are lambdas"
              es
              (lambda (l) (andmap (lambda (e)
                                    (let ([e (if (pair? e) (car e) e)])
                                      (and (pair? e) (eq? (car e) 'lambda))))
                                  l))))
(let ([es (inhabitants '(vec double) 2)])
  (check-pred "terms of (vec double)" es (lambda (l) (= 2 (length l)))))

;; ---- the flagship kernel ----
;; Every definition of examples/kernel-only/lasso-cov.scm, typed together.
;; This is the check the whole exercise was for: the shapes are right --
;; build-S takes four vectors and three numbers, cov-descend three and four
;; -- and it finishes, which it did not before the substitution carried a
;; hash of itself. It runs in the unified numeric reading, where arithmetic
;; unifies rather than branching and the answer is therefore the principal
;; one; the split reading returns a typing too narrow for the callers.
(let* ([forms (with-input-from-file "examples/kernel-only/lasso-cov.scm"
                (lambda ()
                  (let loop ([acc '()])
                    (let ([f (read)])
                      (if (eof-object? f) (reverse acc) (loop (cons f acc)))))))]
       [env (parameterize ([numeric-mode 'unified]) (infer-program forms))]
       [want '((soft-threshold . (-> (num num) num))
               (build-S . (-> ((vec num) (vec num) (vec num) (vec num) num num num) num))
               (build-P . (-> ((vec num) (vec num) (vec num) num num) num))
               (build-G . (-> ((vec num) (vec num) (vec num) (vec num) num num) num))
               (cov-descend . (-> ((vec num) (vec num) (vec num) num num num num) num))
               (enet-descend . (-> ((vec num) (vec num) (vec num) num num num num num) num)))])
  (check-pred "the lasso kernel types" env values)
  (when env
    (for ([w want])
      (check (format "kernel: ~a" (car w)) (assq (car w) env) w))))

(if (zero? failures)
    (printf "rel-infer: all checks pass\n")
    (begin (printf "rel-infer: ~a failed\n" failures) (exit 1)))

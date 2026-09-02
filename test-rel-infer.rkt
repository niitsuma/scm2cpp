#lang racket
;;;; The relational inferencer, checked in both directions.
;;;;
;;;; Forwards it must agree with what algorithm W would say, including the
;;;; int-against-double decision the C++ needs. Backwards it must produce
;;;; terms of a demanded type, which is the direction that exists for the
;;;; proposer tools and which algorithm W does not have. And a stream must
;;;; come out with a type at all: that is what the recursive occurs check in
;;;; vendor/mk-recursive is there for.

(require (file "type-infer-rel.scm")
         (only-in (file "scm-include.rkt") read-source-forms))

(define failures 0)
(define (check label got want)
  (unless (equal? got want)
    (set! failures (add1 failures))
    (printf "FAIL ~a\n  got  ~s\n  want ~s\n" label got want)))
(define (check-pred label got ok?)
  (unless (ok? got)
    (set! failures (add1 failures))
    (printf "FAIL ~a\n  got  ~s\n" label got)))

;; ---- forwards: the base types ----
;; Width is not this pass's business -- see the header -- so a number is num
;; and the int-against-double decision belongs to the widening pass.
(check "number literal" (infer-type 3) 'num)
(check "bool literal"   (infer-type #t) 'bool)
(check "arithmetic"     (infer-type '(+ 1 2)) 'num)
(check "division"       (infer-type '(/ 1 2)) 'num)
(check "comparison"     (infer-type '(< 1 2)) 'bool)
(check "sqrt"           (infer-type '(sqrt 2)) 'num)

;; ---- the enumerating reading, and what it is for ----
;; Under 'split the widths are alternatives, so a term with more than one
;; typing is polymorphic. That is how to ask whether a function has to be a
;; template: square has exactly two typings and is one, and average has four
;; but returns double in all of them, so its result is settled and its
;; parameters are not.
(parameterize ([numeric-mode 'split])
  (check "int literal, enumerated"    (infer-type 3) 'int)
  (check "double literal, enumerated" (infer-type 3.5) 'double)
  (check "int + double widens"        (infer-type '(+ 1 2.5)) 'double)
  (let ([ts (infer-type* '(lambda (x) (* x x)) 5)])
    (check "square is a template, and these are its instances"
           ts '((-> (int) int) (-> (double) double))))
  (let ([ts (infer-type* '(lambda (x y) (/ (+ x y) 2.0)) 6)])
    (check-pred "average returns double however it is called"
                ts (lambda (l) (and (= 4 (length l))
                                    (andmap (lambda (t) (eq? 'double (caddr t))) l)))))
  ;; and a program of any size has no single consistent assignment
  (let ([forms (with-input-from-file "bench/sqrttest.scm"
                 (lambda ()
                   (let loop ([acc '()])
                     (let ([f (read)])
                       (if (eof-object? f) (reverse acc) (loop (cons f acc)))))))])
    (check "a whole program has no enumerated typing" (infer-program forms) #f)
    ;; ...and it does have one when width is left alone, which is the point.
    (check-pred "but it has a typing when width is left alone"
                (parameterize ([numeric-mode 'unified]) (infer-program forms))
                values)))

;; ---- functions ----
(check "one parameter"  (infer-type '(lambda (x) (+ x 1))) '(-> (num) num))
(check "two parameters" (infer-type '(lambda (x y) (< x y))) '(-> (num num) bool))
(check "application"    (infer-type '((lambda (x) (+ x 1)) 2)) 'num)

;; ---- let, and its polymorphism ----
(check "let"            (infer-type '(let ((x 3)) (+ x 1))) 'num)
(check "let-polymorphism"
       (infer-type '(let ((f (lambda (x) x))) (cons (f 1) (f #t))))
       '(pair num bool))

;; ---- the shapes the translator actually meets ----
(check "if"             (infer-type '(if (< 1 2) 3 4)) 'num)
(check "begin"          (infer-type '(begin (newline) 3)) 'num)
(check "named let"      (infer-type '(let loop ((i 0)) (if (< i 10) (loop (+ i 1)) i))) 'num)
;; A literal length is the array's extent; a computed one leaves it open,
;; which is the std::vector case.
(check "make-vector"    (infer-type '(make-vector 3 0.0)) '(vec 3 num))
(check "vector literal" (infer-type '(vector 1 2 3)) '(vec 3 num))
(check-pred "a computed length leaves the extent open"
            (infer-type '(lambda (n) (make-vector n 0.0)))
            (lambda (t) (and (pair? t) (eq? 'vec (car (caddr t)))
                             (not (number? (cadr (caddr t)))))))
(check "vector-ref"     (infer-type '(vector-ref (make-vector 3 0.0) 1)) 'num)
(check "vector-set!"    (infer-type '(vector-set! (make-vector 3 0) 1 2)) 'void)
(check "a loop over a vector"
       (infer-type
        '(let ((v (make-vector 10 0.0)))
           (let loop ((i 1))
             (if (< i 10)
                 (begin (vector-set! v i (+ (vector-ref v (- i 1)) (vector-ref v i)))
                        (loop (+ i 1)))
                 v))))
       '(vec 10 num))

;; ---- a type that contains itself ----
;; Stock miniKanren refuses this one: the occurs check sees the stream
;; inside its own type. Here it comes back as (==> T (pair num (-> () T))).
(define stream-expr '(let ints ((n 0)) (cons n (delay (ints (+ n 1))))))
(check-pred "a stream has a type" (infer-type stream-expr) values)
(check "the head of a stream" (infer-type `(car ,stream-expr)) 'num)
(check-pred "the tail is the same type again"
            (infer-type `(force (cdr ,stream-expr)))
            (lambda (t) (and (pair? t) (eq? (car t) '==>))))

;; ---- ordinary type errors are still errors ----
(check "bool in arithmetic" (infer-type '(+ 1 #t)) #f)
(check "bool as a vector"   (infer-type '(vector-ref #t 0)) #f)

;; ---- backwards ----
(let ([es (inhabitants '(-> (num) num) 3)])
  (check-pred "terms of num -> num" es (lambda (l) (= 3 (length l))))
  (check-pred "and they are lambdas"
              es
              (lambda (l) (andmap (lambda (e)
                                    (let ([e (if (pair? e) (car e) e)])
                                      (and (pair? e) (eq? (car e) 'lambda))))
                                  l))))
(let ([es (inhabitants '(vec 3 num) 2)])
  (check-pred "terms of a three-element vector" es (lambda (l) (= 2 (length l)))))

;; ---- the stream file, whole ----
;; The other program the exercise was for: its types contain themselves.
;; stream-test.scm's own definitions -- an integer stream, and stream-ref
;; walking it -- come out with equi-recursive types, the ==> annotation
;; marking where each type re-enters itself. Two spellings of the same
;; stream type (the recursion rolled at the thunk or at the pair) unify,
;; which is what lets main call stream-ref on what
;; integers-starting-from returns.
(let* ([forms (with-input-from-file "test-scm-code/stream-test.scm"
                (lambda ()
                  (let loop ([acc '()])
                    (let ([f (read)])
                      (if (eof-object? f) (reverse acc) (loop (cons f acc)))))))]
       [env (infer-program forms)])
  (check-pred "stream-test types, whole file" env values)
  (when env
    (check-pred "integers-starting-from returns a recursive stream"
                (cdr (assq 'integers-starting-from env))
                (lambda (t)
                  (and (pair? t)
                       (let loop ([x t])
                         (cond [(and (pair? x) (eq? (car x) '==>)) #t]
                               [(pair? x) (or (loop (car x)) (loop (cdr x)))]
                               [else #f])))))
    (check "stream-ref returns the element type"
           (caddr (cdr (assq 'stream-ref env))) 'num)
    ;; and through the conversion rules the whole interface lands on the
    ;; nominal type the emitter writes as scm2cpp::stream_cell<T>
    (check "stream-car, nominal"
           (type->nominal (cdr (assq 'stream-car env)))
           '(-> ((scm2cpp-stream num)) num))
    (check "stream-cdr, nominal"
           (type->nominal (cdr (assq 'stream-cdr env)))
           '(-> ((scm2cpp-stream num)) (scm2cpp-stream num)))
    (check "integers-starting-from, nominal"
           (type->nominal (cdr (assq 'integers-starting-from env)))
           '(-> (num) (scm2cpp-stream num)))
    ;; an unguarded recursion -- a circular list as plain data -- has no
    ;; C++ value of finite size, and the conversion refuses it
    (check "unguarded recursion is refused"
           (with-handlers ([exn:fail? (lambda (x) 'refused)])
             (type->nominal '(==> x (pair num x))))
           'refused)))

;; ---- the flagship kernel ----
;; Every definition of examples/kernel-only/tfs-lasso-cov.scm, typed together.
;; This is the check the whole exercise was for: the shapes are right --
;; build-S takes four vectors and three numbers, cov-descend three and four
;; -- and it finishes, which it did not before the substitution carried a
;; hash of itself. It runs in the unified numeric reading, where arithmetic
;; unifies rather than branching and the answer is therefore the principal
;; one; the split reading returns a typing too narrow for the callers.
(let* ([forms (read-source-forms "examples/kernel-only/tfs-lasso-cov.scm")]
       [env (parameterize ([numeric-mode 'unified]) (infer-program forms))]
       ;; every vector here is a parameter, so every extent is open: these
       ;; are the std::vector ones, and open is written unsized below.
       [open (lambda (t)
               (let loop ([t t])
                 (cond [(and (symbol? t)
                             (regexp-match? #px"^_\\." (symbol->string t))) 'unsized]
                       [(pair? t) (cons (loop (car t)) (loop (cdr t)))]
                       [else t])))]
       [want '((soft-threshold . (-> (num num) num))
               (build-S . (-> ((vec unsized num) (vec unsized num) (vec unsized num)
                               (vec unsized num) num num num) num))
               (build-P . (-> ((vec unsized num) (vec unsized num) (vec unsized num)
                               num num) num))
               (build-G . (-> ((vec unsized num) (vec unsized num) (vec unsized num)
                               (vec unsized num) num num) num))
               (cov-descend . (-> ((vec unsized num) (vec unsized num) (vec unsized num)
                                   num num num num) num))
               (enet-descend . (-> ((vec unsized num) (vec unsized num) (vec unsized num)
                                    num num num num num) num)))])
  (check-pred "the lasso kernel types" env values)
  (when env
    (for ([w want])
      (check (format "kernel: ~a" (car w)) (open (assq (car w) env)) w))))

(if (zero? failures)
    (printf "rel-infer: all checks pass\n")
    (begin (printf "rel-infer: ~a failed\n" failures) (exit 1)))

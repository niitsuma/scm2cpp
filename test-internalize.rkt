#lang racket
;;;; The scratch-internalisation consumer, checked end to end: the
;;;; workspace parameter leaves the signature, the callers stop
;;;; allocating it, and the program prints exactly what it printed.

(require (file "scratch-internalize.scm"))

(define prog
  '(begin
     (define (kern x beta q n)
       ;; q is workspace: filled and read here, never seen outside
       (do ((i 0 (+ i 1))) ((= i n))
         (vector-set! q i (* 2.0 (vector-ref x i))))
       (do ((i 0 (+ i 1))) ((= i n))
         (vector-set! beta i (+ (vector-ref beta i) (vector-ref q i))))
       0)
     (define (main)
       (let ((x (vector 1.0 2.0 3.0))
             (b (make-vector 3 0.0))
             (q (make-vector 3 0.0)))
         (kern x b q 3)
         (do ((i 0 (+ i 1))) ((= i 3))
           (display (vector-ref b i)) (display " "))
         (newline)))
     (main)))

(define prog2 (internalize-scratch prog 'kern))
(unless prog2 (printf "NG: internalisation refused\n") (exit 1))

;; the signature must have shrunk and the call site with it
(define (arity-of p f)
  (for/or ([e (match p [`(begin ,fs ...) fs])])
    (match e [`(define (,(== f) ,ps ...) ,_ ...) (length ps)] [_ #f])))
(unless (= 3 (arity-of prog2 'kern))
  (printf "NG: signature did not shrink: ~a\n" (arity-of prog2 'kern)) (exit 1))
(when (regexp-match? #rx"\\(kern x b q" (format "~s" prog2))
  (printf "NG: a call site still passes q\n") (exit 1))

(define (run p)
  (with-output-to-string
    (lambda ()
      (parameterize ([current-namespace (make-base-namespace)])
        (for ([f (match p [`(begin ,fs ...) fs])]) (eval f))))))
(define a (run prog))
(define b (run prog2))
(if (equal? a b)
    (begin (printf "internalize: outputs equal (~a), arity 4 -> 3\n"
                   (string-trim a))
           (exit 0))
    (begin (printf "NG: outputs differ: ~a vs ~a\n" a b) (exit 1)))

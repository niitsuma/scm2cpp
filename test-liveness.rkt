#lang racket
;;;; Unit checks for the parameter-liveness pass: which written parameters
;;;; are outputs (somebody reads them afterwards) and which are scratch.
;;;; Each scenario is a tiny whole program; expectations are exact.
;;;; Exits nonzero on the first miss, printing what differed.

(require (file "scm2cpp-match.scm"))

(define failures 0)
(define (chk name prog fn outs scr)
  (compute-param-liveness! prog)
  (let ([o (function-output-params fn)]
        [s (function-scratch-params fn)])
    (unless (and (equal? o outs) (equal? s scr))
      (set! failures (add1 failures))
      (printf "NG ~a: ~a expected out=~a scr=~a got out=~a scr=~a\n"
              name fn outs scr o s))))

;; kern writes beta (1) and resid (2); x (0) is read only.
(define kern
  '(define (kern x beta resid n)
     (do ((i 0 (+ i 1))) ((= i n))
       (vector-set! beta i (vector-ref x i))
       (vector-set! resid i (- (vector-ref resid i) 1.0)))))

;; 1. main reads both afterwards: both outputs.
(chk "reads-both"
     `(begin ,kern
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0))
                     (r (make-vector 4 2.0)))
                 (kern x b r 4)
                 (display (vector-ref b 0))
                 (display (vector-ref r 0)))))
     'kern '(1 2) '())

;; 2. main reads only beta: resid is scratch.
(chk "reads-beta-only"
     `(begin ,kern
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0))
                     (r (make-vector 4 2.0)))
                 (kern x b r 4)
                 (display (vector-ref b 0)))))
     'kern '(1) '(2))

;; 3. no main: a library; every written parameter is an output.
(chk "library" `(begin ,kern) 'kern '(1 2) '())

;; 4. the call sits in a loop and nothing is read after: the next
;;    iteration reads what the last one wrote, so both stay outputs.
(chk "loop-carried"
     `(begin ,kern
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0))
                     (r (make-vector 4 2.0)))
                 (do ((k 0 (+ k 1))) ((= k 3))
                   (kern x b r 4)))))
     'kern '(1 2) '())

;; 5. an alias taken before the call reads resid behind the ordered
;;    check's back: resid must stay an output.
(chk "alias"
     `(begin ,kern
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0))
                     (r (make-vector 4 2.0)))
                 (let ((w r))
                   (kern x b r 4)
                   (display (vector-ref b 0))
                   (display (vector-ref w 0))))))
     'kern '(1 2) '())

;; 6. transitivity: main -> mid -> kern, and main never reads r.
;;    kern's write is unobservable through two levels.
(chk "transitive-scratch"
     `(begin ,kern
             (define (mid x b r n) (kern x b r n) 0)
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0))
                     (r (make-vector 4 2.0)))
                 (mid x b r 4)
                 (display (vector-ref b 0)))))
     'kern '(1) '(2))

;; 7. a global vector is always observable.
(chk "global"
     `(begin (define gv (make-vector 4 0.0))
             ,kern
             (define (main)
               (let ((x (make-vector 4 1.0)) (b (make-vector 4 0.0)))
                 (kern x b gv 4)
                 (display (vector-ref b 0)))))
     'kern '(1 2) '())

(if (zero? failures)
    (begin (displayln "liveness: all checks pass") (exit 0))
    (exit 1))

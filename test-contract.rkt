#lang racket
;;;; Units for the intermediate general contraction: the separable
;;;; integral-image build loses its intermediate row-prefix array,
;;;; the refusals refuse, and the oracle confirms fusion moved no
;;;; number -- bitwise, since fusion reorders no arithmetic.

(require (file "rewrite-contract.scm")
         (file "rewrite-driver.scm"))

;; the separable integral image: per-row prefix sums (producer), then
;; per-row segment sums and the column accumulation (consumers)
(define producer
  '(range-for (a H)
     (begin
       (array-set! rp a 0 0.0)
       (range-for (t W)
         (array-set! rp a (+ t 1)
                     (+ (array-ref rp a t) (array-ref img a t)))))))
(define seg-consumer
  '(range-for (a2 H)
     (vector-set! seg a2 (- (array-ref rp a2 c2) (array-ref rp a2 c1)))))
(define ii-consumer
  '(range-for (a3 H)
     (range-for (t (+ W 1))
       (array-set! ii a3 t
                   (+ (if (= a3 0) 0.0 (array-ref ii (- a3 1) t))
                      (array-ref rp a3 t))))))
(define stmts (list producer seg-consumer ii-consumer))
(define dims '((rp (H (+ W 1)))))

(define out (contract-axis stmts dims))
(unless out (printf "NG: integral-image contraction refused\n") (exit 1))
(unless (= 1 (length out))
  (printf "NG: expected one fused statement\n") (exit 1))
(when (regexp-match #rx"rp" (format "~s" out))
  (printf "NG: the contracted array survived\n") (exit 1))

;; refusals
;; a read of the previous row is a window, not an aligned consumer
(when (contract-axis
       (list producer
             '(range-for (a2 H)
                (vector-set! seg a2 (array-ref rp (- a2 1) c2))))
       dims)
  (printf "NG: a neighbouring-row read was fused\n") (exit 1))
;; extent mismatch
(when (contract-axis
       (list producer
             '(range-for (a2 H2)
                (vector-set! seg a2 (array-ref rp a2 c2))))
       dims)
  (printf "NG: mismatched extents fused\n") (exit 1))
;; a stray read after a non-consumer statement keeps the array whole
(when (contract-axis
       (append stmts
               '((display 0)
                 (range-for (q H) (vector-set! zz q (array-ref rp q 0)))))
       dims)
  (printf "NG: a stray later read was orphaned\n") (exit 1))
;; a consumer that writes the array is no consumer
(when (contract-axis
       (list producer
             '(range-for (a2 H) (array-set! rp a2 0 1.0)))
       dims)
  (printf "NG: a writer was taken for a consumer\n") (exit 1))

;; ---------------- oracle: fusion moves nothing ----------------

(define (run-oracle prog)
  (define f (make-temporary-file "ctr~a.scm"))
  (with-output-to-file f #:exists 'replace
    (lambda () (for ([s prog]) (writeln s))))
  (define o (with-output-to-string
              (lambda ()
                (system* (find-executable-path "racket")
                         "test-oracle.rkt" "run" (path->string f)))))
  (delete-file f)
  o)

(define (program body)
  `((define (main)
      (let ((H 4) (W 5) (c1 1) (c2 4)
            (img (vector 1.0 2.0 0.5 -1.0 3.0
                         0.0 1.5 2.5 1.0 -2.0
                         4.0 0.5 0.5 2.0 1.0
                         -1.0 1.0 3.0 0.0 2.0))
            (rp (make-vector 24 0.0))
            (seg (make-vector 4 0.0))
            (ii (make-vector 24 0.0)))
        (with-arrays ((img (H W)) (rp (H (+ W 1))) (ii (H (+ W 1))))
          ,@body
          0)
        (do ((k 0 (+ k 1))) ((= k 4))
          (display (vector-ref seg k)) (display " "))
        (do ((k 0 (+ k 1))) ((= k 24))
          (display (vector-ref ii k)) (display " "))
        (newline)))
    (main)))
(let ([a (run-oracle (program stmts))]
      [b (run-oracle (program out))])
  (unless (and (equal? a b) (regexp-match #rx"[0-9]" a))
    (printf "NG: contraction changed output\n~s\n~s\n" a b) (exit 1)))

;; ---------------- through the driver ----------------

(let-values ([(d log) (derive-fixpoint/log stmts 'resid 'beta
                                           #:dims dims)])
  (unless (equal? log '(contract))
    (printf "NG: driver firing log ~s\n" log) (exit 1)))

(printf "PASS contract-unit\n")

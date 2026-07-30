;; How foo.hpp is seen from Scheme: the type, the operations, a pure
;; Scheme model of each operation, and a test the checking gate runs
;; through both the model and the compiled C++.

(deftype matrix
  (cpp "foo::Matrix< ~a >")
  (header "\"foo.hpp\""))

(defop mat-new
  (sig (int int) (matrix double))
  (cpp "foo::Matrix< double >(~a,~a)"))

(defop mat-ref
  (sig ((matrix double) int int) double)
  (cpp "~a.at(~a,~a)"))

(defop mat-set!
  (sig ((matrix double) int int double) void)
  (cpp "~a.set(~a,~a,~a)")
  (mutates 0))

(defop mat-rows
  (sig ((matrix double)) int)
  (cpp "~a.rows()"))

;; The models represent a matrix as (vector rows cols flat-data).
(model mat-new (lambda (r c) (vector r c (make-vector (* r c) 0.0))))
(model mat-ref (lambda (m i j)
                 (vector-ref (vector-ref m 2) (+ (* i (vector-ref m 1)) j))))
(model mat-set! (lambda (m i j v)
                  (vector-set! (vector-ref m 2) (+ (* i (vector-ref m 1)) j) v)))
(model mat-rows (lambda (m) (vector-ref m 0)))

;; A helper that mutates its matrix parameter: this is the test that
;; catches by-value parameter passing, where the helper would write a
;; private copy and the caller would read zeros.
(binding-test
  (define (fill-row m r ncol v)
    (do ((j 0 (+ j 1))) ((= j ncol))
      (mat-set! m r j v))
    0)
  (define (main)
    (let ((m (mat-new 2 3)))
      (fill-row m 1 3 7.5)
      (display (mat-ref m 1 0)) (newline)
      (display (mat-ref m 1 2)) (newline)
      0))
  (main))

(binding-test
  (define (main)
    (let ((m (mat-new 3 4)))
      (mat-set! m 0 0 1.5)
      (mat-set! m 2 3 2.5)
      (mat-set! m 1 2 0.25)
      (display (+ (mat-ref m 0 0)
                  (+ (* 10.0 (mat-ref m 2 3))
                     (* 100.0 (mat-ref m 1 2)))))
      (newline)
      (display (mat-rows m))
      (newline)
      0))
  (main))

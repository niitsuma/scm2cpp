;; sparse.scm on a 6 x 4 matrix with eight nonzeros, compressed here
;; from the dense one by loops (rows with their columns in decreasing
;; order, so the indices are not sorted): A'A from two blocks of rows
;; into two G's summed here (as the caller's threads do), A A' (the same
;; call on the CSC) in one block, each mirrored here, then A B and A' C
;; for dense B (4 x 2) and C (6 x 2).
(include "../examples/kernel-only/sparse.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

;; the lower triangle of G (m x m) from the upper
(define (mirror g m)
  (do ((a 0 (+ a 1))) ((= a m))
    (do ((b 0 (+ b 1))) ((= b a))
      (vector-set! g (+ (* a m) b) (vector-ref g (+ (* b m) a)))))
  0)

;; CSR of the n x p dense D into RP, CI, V (columns descending in a row)
(define (compress d rp ci v n p)
  (let ((s 0))
    (do ((i 0 (+ i 1))) ((= i n))
      (vector-set! rp i s)
      (do ((j (- p 1) (- j 1))) ((< j 0))
        (if (not (= (vector-ref d (+ (* i p) j)) 0.0))
            (begin (vector-set! ci s j) (vector-set! v s (vector-ref d (+ (* i p) j))) (set! s (+ s 1)))
            0)))
    (vector-set! rp n s)
    s))

(define (main)
  (let ((d0 (vector 0.5 0.0 -1.25 0.0   0.0 2.0 0.0 0.0   0.75 0.0 0.0 -0.5
                    0.0 0.0 1.5 0.25   -1.0 0.0 0.0 0.0   0.0 0.0 0.0 0.0))
        (n 6) (p 4) (z 11))
    (let ((d (make-vector (* n p) 0.0)) (dt (make-vector (* p n) 0.0))
          (rp (make-vector (+ n 1) 0)) (ci (make-vector z 0)) (v (make-vector z 0.0))
          (cp (make-vector (+ p 1) 0)) (ri (make-vector z 0)) (cv (make-vector z 0.0))
          (g (make-vector (* p p) 0.0)) (g2 (make-vector (* p p) 0.0))
          (h (make-vector (* n n) 0.0))
          (b (make-vector (* p 2) 0.0)) (c (make-vector (* n 2) 0.0))
          (ab (make-vector (* n 2) 0.0)) (atc (make-vector (* p 2) 0.0)))
      (do ((s 0 (+ s 1))) ((= s (* n p))) (vector-set! d s (vector-ref d0 s)))
      (do ((i 0 (+ i 1))) ((= i n))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! dt (+ (* j n) i) (vector-ref d (+ (* i p) j)))))
      (do ((s 0 (+ s 1))) ((= s (* p 2))) (vector-set! b s (- (* 0.25 (exact->inexact s)) 0.5)))
      (do ((s 0 (+ s 1))) ((= s (* n 2))) (vector-set! c s (+ (* 0.125 (exact->inexact s)) 0.25)))
      (display (compress d rp ci v n p)) (newline)
      (compress dt cp ri cv p n)
      (csr-gram rp ci v g p 0 3)
      (csr-gram rp ci v g2 p 3 n)
      (do ((s 0 (+ s 1))) ((= s (* p p))) (vector-set! g s (+ (vector-ref g s) (vector-ref g2 s))))
      (mirror g p)
      (show g (* p p))
      (csr-gram cp ri cv h n 0 p)
      (mirror h n)
      (show h (* n n))
      (csr-mm rp ci v b ab n 2)
      (show ab (* n 2))
      (csr-mm cp ri cv c atc p 2)
      (show atc (* p 2))
      0)))

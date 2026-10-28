;;;; Sparse designs in compressed rows (CSR): the two products the
;;;; Gram-route estimators need, so that a sparse X is read once into the
;;;; same p x p matrix a dense one gives.
;;;;
;;;;   csr-gram  the upper triangle of the rows R0..R1-1's part of
;;;;             G = A'A: each row's outer product, its entries taken in
;;;;             pairs.  The rows are read in order, once (the work is
;;;;             sum_i nnz_i^2 / 2); the writes land anywhere in G, so
;;;;             blocks of rows run side by side only into separate G's,
;;;;             which the caller's threads hold and sum, mirroring the
;;;;             triangle.  X X' is the same call on X' (X's CSC).
;;;;   csr-mm    C = A B for A in CSR and a dense B (rows of A
;;;;             independent, parallel under -P omp); A' B is the call
;;;;             on A's CSC.
;;;;
;;;; Index arrays are 0-based int, as scipy.sparse holds them (int32);
;;;; within a row the indices need not be sorted, and a repeated one adds.
;;;;

;; G (p x p) gets the rows R0..R1-1's outer products added into its
;; upper triangle: A in CSR (RP, CI, V).  No loop here is parallel: the
;; caller's threads are, each with its own G.
(define (csr-gram rp ci v g p r0 r1)
  (do ((i r0 (+ i 1))) ((= i r1))
    (do ((u (vector-ref rp i) (+ u 1))) ((= u (vector-ref rp (+ i 1))))
      (let ((a (vector-ref ci u)) (x (vector-ref v u)))
        (do ((w (vector-ref rp i) (+ w 1))) ((= w (vector-ref rp (+ i 1))))
          (let ((b (vector-ref ci w)))
            (if (>= b a)
                (vector-set! g (+ (* a p) b) (+ (vector-ref g (+ (* a p) b)) (* x (vector-ref v w))))
                0))))))
  0)

;; C (n x k) gets A B: A (n rows) in CSR (RP, CI, V), B dense (? x k)
(define (csr-mm rp ci v b c n k)
  (do ((s 0 (+ s 1))) ((= s (* n k))) (vector-set! c s 0.0))
  (do ((i 0 (+ i 1))) ((= i n))
    (do ((u (vector-ref rp i) (+ u 1))) ((= u (vector-ref rp (+ i 1))))
      (let ((j (vector-ref ci u)) (x (vector-ref v u)))
        (do ((q 0 (+ q 1))) ((= q k))
          (vector-set! c (+ (* i k) q) (+ (vector-ref c (+ (* i k) q)) (* x (vector-ref b (+ (* j k) q)))))))))
  0)

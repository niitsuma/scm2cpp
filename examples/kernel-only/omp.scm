;;;; Orthogonal matching pursuit over the Gram matrix, whole:
;;;; scikit-learn's OrthogonalMatchingPursuit for n > p
;;;; (precompute="auto"), that is orthogonal_mp_gram and _gram_omp,
;;;; written out in the subset.
;;;;
;;;; G = X'X and X'y are formed by products (--blas: dsyrk and dgemv).
;;;; Each step takes the column whose correlation with the residual,
;;;; alpha, is largest in absolute value (the first such, as np.argmax),
;;;; and stops early when that column is already in, or its correlation
;;;; is below the machine epsilon; it extends the Cholesky factor L of
;;;; the selected columns' Gram block by one row (a triangular solve
;;;; against G's row), stopping if the new column depends on the others;
;;;; swaps the column to the front of G and of X'y as _gram_omp does;
;;;; solves L L' gamma = (X'y)[:k]; and recomputes
;;;; alpha = X'y - G[:, :k] gamma.  It ends after KMAX columns.
;;;;
;;;; X is n rows of p, centred by the caller when an intercept is fitted
;;;; (as LinearRegression's preprocessing does); COEF gets the
;;;; coefficients.  Returns the number of columns selected.
;;;;
;;;;[ja] Gram 行列の上の直交マッチング追跡全体: scikit-learn の
;;;;[ja] OrthogonalMatchingPursuit(n > p、precompute="auto")、つまり
;;;;[ja] orthogonal_mp_gram と _gram_omp をそのままサブセットで書いたもの。
;;;;[ja] G = X'X と X'y は積(--blas で dsyrk と dgemv)。各ステップで残差との
;;;;[ja] 相関 alpha の絶対値が最大の列を取り、コレスキー因子を 1 行伸ばし、
;;;;[ja] G と X'y の先頭に入れ替え、L L' gamma = X'y[:k] を解き、alpha を
;;;;[ja] 計算し直す。KMAX 列で終了。

(define (omp x y coef kmax n p)
  (let ((g (make-vector (* p p) 0.0))
        (xy (make-vector p 0.0))
        (alpha (make-vector p 0.0))
        (beta (make-vector p 0.0))
        (index (make-vector p 0))
        (l (make-vector (* kmax kmax) 0.0))
        (gamma (make-vector kmax 0.0))
        (z (make-vector kmax 0.0))
        (eps 2.220446049250313e-16)
        (na 0) (done 0))
    (with-arrays ((x (n p)) (y (n)) (g (p p)) (xy (p)))
      (array-set! g (matmul (transpose x) x))
      (array-set! xy (matmul (transpose x) y)))
    (do ((j 0 (+ j 1))) ((= j p))
      (vector-set! index j j)
      (vector-set! alpha j (vector-ref xy j)))
    (do () ((= done 1))
      ;; the column of largest |alpha|, the first one
      (let ((lam 0) (best -1.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((a (vector-ref alpha j)))
            (let ((aa (if (< a 0.0) (- 0.0 a) a)))
              (if (> aa best) (begin (set! best aa) (set! lam j)) 0))))
        (if (or (< lam na) (< (* (vector-ref alpha lam) (vector-ref alpha lam)) eps))
            (set! done 1)
            (begin
              ;; L grows by a row: L[na, :na] solves L[:na,:na] v = G[lam, :na]
              (if (> na 0)
                  (let ((v 0.0))
                    (do ((i 0 (+ i 1))) ((= i na))
                      (let ((t (vector-ref g (+ (* lam p) i))))
                        (do ((s 0 (+ s 1))) ((= s i))
                          (set! t (- t (* (vector-ref l (+ (* i kmax) s)) (vector-ref l (+ (* na kmax) s))))))
                        (let ((li (/ t (vector-ref l (+ (* i kmax) i)))))
                          (vector-set! l (+ (* na kmax) i) li)
                          (set! v (+ v (* li li))))))
                    (let ((lkk (- (vector-ref g (+ (* lam p) lam)) v)))
                      (if (<= lkk eps)
                          (set! done 1)
                          (vector-set! l (+ (* na kmax) na) (sqrt lkk)))))
                  (vector-set! l 0 (sqrt (vector-ref g (+ (* lam p) lam)))))
              (if (= done 0)
                  (begin
                    ;; the column to the front: rows and columns of G, X'y, the index
                    (do ((j 0 (+ j 1))) ((= j p))
                      (let ((grow (vector-ref g (+ (* na p) j))))
                        (vector-set! g (+ (* na p) j) (vector-ref g (+ (* lam p) j)))
                        (vector-set! g (+ (* lam p) j) grow)))
                    (do ((j 0 (+ j 1))) ((= j p))
                      (let ((gcol (vector-ref g (+ (* j p) na))))
                        (vector-set! g (+ (* j p) na) (vector-ref g (+ (* j p) lam)))
                        (vector-set! g (+ (* j p) lam) gcol)))
                    (let ((itmp (vector-ref index na)))
                      (vector-set! index na (vector-ref index lam))
                      (vector-set! index lam itmp))
                    (let ((xtmp (vector-ref xy na)))
                      (vector-set! xy na (vector-ref xy lam))
                      (vector-set! xy lam xtmp))
                    (set! na (+ na 1))
                    ;; gamma: L L' gamma = X'y[:na]
                    (do ((i 0 (+ i 1))) ((= i na))
                      (let ((t (vector-ref xy i)))
                        (do ((s 0 (+ s 1))) ((= s i))
                          (set! t (- t (* (vector-ref l (+ (* i kmax) s)) (vector-ref z s)))))
                        (vector-set! z i (/ t (vector-ref l (+ (* i kmax) i))))))
                    (do ((ii 0 (+ ii 1))) ((= ii na))
                      (let ((i (- (- na 1) ii)))
                        (let ((t (vector-ref z i)))
                          (do ((s (+ i 1) (+ s 1))) ((>= s na))
                            (set! t (- t (* (vector-ref l (+ (* s kmax) i)) (vector-ref gamma s)))))
                          (vector-set! gamma i (/ t (vector-ref l (+ (* i kmax) i)))))))
                    ;; alpha = X'y - G[:, :na] gamma
                    (do ((j 0 (+ j 1))) ((= j p))
                      (let ((acc 0.0))
                        (do ((s 0 (+ s 1))) ((= s na))
                          (set! acc (+ acc (* (vector-ref g (+ (* j p) s)) (vector-ref gamma s)))))
                        (vector-set! beta j acc)
                        (vector-set! alpha j (- (vector-ref xy j) acc))))
                    (if (= na kmax) (set! done 1) 0))
                  0)))))
    (do ((j 0 (+ j 1))) ((= j p)) (vector-set! coef j 0.0))
    (do ((s 0 (+ s 1))) ((= s na))
      (vector-set! coef (vector-ref index s) (vector-ref gamma s)))
    na))

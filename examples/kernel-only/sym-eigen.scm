;;;; The symmetric eigenproblem, for the kernels that need one
;;;; (fastica.scm's whitening and decorrelation, pca.scm's covariance):
;;;; Householder reduction to tridiagonal form with the transformation
;;;; accumulated (Numerical Recipes' tred2), then the implicit QL
;;;; iteration with Wilkinson shifts on the tridiagonal (tqli), the
;;;; rotations applied to the rows of the transposed transformation so
;;;; that they run along memory.  A deflation test is |e| + dd = dd.
;;;; eig-order then sorts the eigenvalues into decreasing order.
;;;;
;;;;[ja] 対称固有値問題(fastica.scm の白色化と無相関化、pca.scm の共分散で
;;;;[ja] 使う): Householder 変換で三重対角化(変換を蓄積、Numerical Recipes の
;;;;[ja] tred2)し、陰的 QL 法(tqli)。回転は転置した変換行列の行に掛けて
;;;;[ja] メモリ順に走らせる。eig-order は固有値を降順に並べる。

;; sqrt(a^2 + b^2) without overflow
(define (eig-hypot a b)
  (let ((aa (if (< a 0.0) (- 0.0 a) a)) (bb (if (< b 0.0) (- 0.0 b) b)))
    (if (> aa bb)
        (* aa (sqrt (+ 1.0 (* (/ bb aa) (/ bb aa)))))
        (if (= bb 0.0) 0.0 (* bb (sqrt (+ 1.0 (* (/ aa bb) (/ aa bb)))))))))

;; A (m x m, symmetric) is destroyed; V gets the eigenvectors as columns
;; (V[j m + c] is entry j of vector c), EV the eigenvalues; E is m of
;; scratch
(define (sym-eigen a v ev e m)
  ;; tred2: a becomes the transformation, ev the diagonal, e the off-diagonal
  (do ((ii 0 (+ ii 1))) ((= ii (- m 1)))
    (let ((i (- (- m 1) ii)))
      (let ((l (- i 1)) (h 0.0) (scale 0.0))
        (if (> l 0)
            (begin
              (do ((k 0 (+ k 1))) ((> k l))
                (let ((ak (vector-ref a (+ (* i m) k))))
                  (set! scale (+ scale (if (< ak 0.0) (- 0.0 ak) ak)))))
              (if (= scale 0.0)
                  (vector-set! e i (vector-ref a (+ (* i m) l)))
                  (begin
                    (do ((k 0 (+ k 1))) ((> k l))
                      (vector-set! a (+ (* i m) k) (/ (vector-ref a (+ (* i m) k)) scale))
                      (set! h (+ h (* (vector-ref a (+ (* i m) k)) (vector-ref a (+ (* i m) k))))))
                    (let ((f (vector-ref a (+ (* i m) l))))
                      (let ((g (if (>= f 0.0) (- 0.0 (sqrt h)) (sqrt h))))
                        (vector-set! e i (* scale g))
                        (set! h (- h (* f g)))
                        (vector-set! a (+ (* i m) l) (- f g))
                        (let ((ff 0.0))
                          (do ((j 0 (+ j 1))) ((> j l))
                            (vector-set! a (+ (* j m) i) (/ (vector-ref a (+ (* i m) j)) h))
                            (let ((gg 0.0))
                              (do ((k 0 (+ k 1))) ((> k j))
                                (set! gg (+ gg (* (vector-ref a (+ (* j m) k)) (vector-ref a (+ (* i m) k))))))
                              (do ((k (+ j 1) (+ k 1))) ((> k l))
                                (set! gg (+ gg (* (vector-ref a (+ (* k m) j)) (vector-ref a (+ (* i m) k))))))
                              (vector-set! e j (/ gg h))
                              (set! ff (+ ff (* (vector-ref e j) (vector-ref a (+ (* i m) j)))))))
                          (let ((hh (/ ff (+ h h))))
                            (do ((j 0 (+ j 1))) ((> j l))
                              (let ((f2 (vector-ref a (+ (* i m) j))))
                                (let ((g2 (- (vector-ref e j) (* hh f2))))
                                  (vector-set! e j g2)
                                  (do ((k 0 (+ k 1))) ((> k j))
                                    (vector-set! a (+ (* j m) k)
                                                 (- (vector-ref a (+ (* j m) k))
                                                    (+ (* f2 (vector-ref e k)) (* g2 (vector-ref a (+ (* i m) k)))))))))))))))))
            (vector-set! e i (vector-ref a (+ (* i m) l))))
        (vector-set! ev i h))))
  (vector-set! ev 0 0.0)
  (vector-set! e 0 0.0)
  (do ((i 0 (+ i 1))) ((= i m))
    (if (not (= (vector-ref ev i) 0.0))
        (do ((j 0 (+ j 1))) ((= j i))
          (let ((g3 0.0))
            (do ((k 0 (+ k 1))) ((= k i))
              (set! g3 (+ g3 (* (vector-ref a (+ (* i m) k)) (vector-ref a (+ (* k m) j))))))
            (do ((k 0 (+ k 1))) ((= k i))
              (vector-set! a (+ (* k m) j) (- (vector-ref a (+ (* k m) j)) (* g3 (vector-ref a (+ (* k m) i))))))))
        0)
    (vector-set! ev i (vector-ref a (+ (* i m) i)))
    (vector-set! a (+ (* i m) i) 1.0)
    (do ((j 0 (+ j 1))) ((= j i))
      (vector-set! a (+ (* j m) i) 0.0)
      (vector-set! a (+ (* i m) j) 0.0)))
  ;; the transformation transposed into V: row c of V is column c of a
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j 0 (+ j 1))) ((= j m))
      (vector-set! v (+ (* j m) i) (vector-ref a (+ (* i m) j)))))
  ;; tqli on (ev, e), the rotations on the rows of V
  (do ((i 1 (+ i 1))) ((= i m)) (vector-set! e (- i 1) (vector-ref e i)))
  (vector-set! e (- m 1) 0.0)
  (do ((l 0 (+ l 1))) ((= l m))
    (let ((fin 0) (iter 0))
      (do () ((or (= fin 1) (> iter 60)))
        (let ((mm l) (found 0))
          (do () ((or (= found 1) (>= mm (- m 1))))
            (let ((dd (+ (eig-abs (vector-ref ev mm)) (eig-abs (vector-ref ev (+ mm 1))))))
              (if (= (+ (eig-abs (vector-ref e mm)) dd) dd)
                  (set! found 1)
                  (set! mm (+ mm 1)))))
          (if (= mm l)
              (set! fin 1)
              (begin
                (set! iter (+ iter 1))
                (let ((g (/ (- (vector-ref ev (+ l 1)) (vector-ref ev l)) (* 2.0 (vector-ref e l)))))
                  (let ((r (eig-hypot g 1.0)))
                    (let ((g4 (+ (- (vector-ref ev mm) (vector-ref ev l))
                                 (/ (vector-ref e l) (+ g (if (>= g 0.0) (eig-abs r) (- 0.0 (eig-abs r))))))))
                      (let ((s 1.0) (c 1.0) (pp 0.0) (gq g4) (under 0) (i (- mm 1)))
                        (do () ((or (= under 1) (< i l)))
                          (let ((f (* s (vector-ref e i))) (b (* c (vector-ref e i))))
                            (let ((r2 (eig-hypot f gq)))
                              (vector-set! e (+ i 1) r2)
                              (if (= r2 0.0)
                                  (begin
                                    (vector-set! ev (+ i 1) (- (vector-ref ev (+ i 1)) pp))
                                    (vector-set! e mm 0.0)
                                    (set! under 1))
                                  (begin
                                    (set! s (/ f r2))
                                    (set! c (/ gq r2))
                                    (let ((g5 (- (vector-ref ev (+ i 1)) pp)))
                                      (let ((r3 (+ (* (- (vector-ref ev i) g5) s) (* 2.0 (* c b)))))
                                        (set! pp (* s r3))
                                        (vector-set! ev (+ i 1) (+ g5 pp))
                                        (set! gq (- (* c r3) b))))
                                    (do ((k 0 (+ k 1))) ((= k m))
                                      (let ((zf (vector-ref v (+ (* (+ i 1) m) k)))
                                            (zi (vector-ref v (+ (* i m) k))))
                                        (vector-set! v (+ (* (+ i 1) m) k) (+ (* s zi) (* c zf)))
                                        (vector-set! v (+ (* i m) k) (- (* c zi) (* s zf)))))
                                    (set! i (- i 1)))))))
                        (if (= under 0)
                            (begin
                              (vector-set! ev l (- (vector-ref ev l) pp))
                              (vector-set! e l gq)
                              (vector-set! e mm 0.0))
                            0)))))))))))
  ;; V's rows are the eigenvectors: transpose to columns
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j (+ i 1) (+ j 1))) ((>= j m))
      (let ((tmp (vector-ref v (+ (* i m) j))))
        (vector-set! v (+ (* i m) j) (vector-ref v (+ (* j m) i)))
        (vector-set! v (+ (* j m) i) tmp))))
  0)

(define (eig-abs a) (if (< a 0.0) (- 0.0 a) a))

;; ORD gets the indices of EV in decreasing order (a selection sort, ties
;; to the lower index)
(define (eig-order ev ord m)
  (do ((j 0 (+ j 1))) ((= j m)) (vector-set! ord j j))
  (do ((j 0 (+ j 1))) ((= j m))
    (let ((best j))
      (do ((r (+ j 1) (+ r 1))) ((>= r m))
        (if (> (vector-ref ev (vector-ref ord r)) (vector-ref ev (vector-ref ord best))) (set! best r) 0))
      (let ((tmp (vector-ref ord j)))
        (vector-set! ord j (vector-ref ord best))
        (vector-set! ord best tmp))))
  0)

;; The K largest eigenpairs of A (m x m, symmetric, destroyed): EV the
;; values in decreasing order, V (m x K) their vectors as columns; E is m
;; of scratch.  Here the whole problem and a selection; under --blas the
;; call is LAPACK's dsyevr, which computes only these K (scipy's eigh
;; with subset_by_index, as KernelPCA calls it).
;;[ja] 大きい方から K 個の固有対(EV は降順、V は m x K で列が固有ベクトル)。
;;[ja] ここでは全部を解いて選ぶ。--blas では dsyevr がこの K 個だけを求める。
(define (sym-eigen-top a v ev e m k)
  (let ((vf (make-vector (* m m) 0.0))
        (evf (make-vector m 0.0))
        (ord (make-vector m 0)))
    (sym-eigen a vf evf e m)
    (eig-order evf ord m)
    (do ((c 0 (+ c 1))) ((= c k))
      (let ((col (vector-ref ord c)))
        (vector-set! ev c (vector-ref evf col))
        (do ((j 0 (+ j 1))) ((= j m))
          (vector-set! v (+ (* j k) c) (vector-ref vf (+ (* j m) col))))))
    0))

;; The generalized problem A v = lam B v for A symmetric and B symmetric
;; positive definite (m x m, both destroyed): V the vectors as columns,
;; scaled so that V'BV = I, EV the values (in no set order, as
;; sym-eigen's); E is m of scratch.  Here by reduction: B = L L'
;; (Cholesky, in B), C = L^-1 A L^-T (in A), C = W diag(EV) W', V = L^-T W.
;; Under --blas the call is LAPACK's dsygvd (scipy's eigh(a, b)).
;;[ja] 一般化固有値問題 A v = lam B v(B は正定値)。B = L L' で C = L^-1 A L^-T に
;;[ja] 帰着し、V = L^-T W(V'BV = I)。--blas では dsygvd。
(define (sym-eigen-gen a b v ev e m)
  ;; B = L L', L in the lower triangle of B
  (do ((j 0 (+ j 1))) ((= j m))
    (let ((d (vector-ref b (+ (* j m) j))))
      (do ((l 0 (+ l 1))) ((= l j))
        (set! d (- d (* (vector-ref b (+ (* j m) l)) (vector-ref b (+ (* j m) l))))))
      (vector-set! b (+ (* j m) j) (sqrt d))
      (do ((i (+ j 1) (+ i 1))) ((>= i m))
        (let ((s (vector-ref b (+ (* i m) j))))
          (do ((l 0 (+ l 1))) ((= l j))
            (set! s (- s (* (vector-ref b (+ (* i m) l)) (vector-ref b (+ (* j m) l))))))
          (vector-set! b (+ (* i m) j) (/ s (vector-ref b (+ (* j m) j))))))))
  ;; A <- L^-1 A: forward substitution down each column
  (do ((c 0 (+ c 1))) ((= c m))
    (do ((i 0 (+ i 1))) ((= i m))
      (let ((s (vector-ref a (+ (* i m) c))))
        (do ((l 0 (+ l 1))) ((= l i))
          (set! s (- s (* (vector-ref b (+ (* i m) l)) (vector-ref a (+ (* l m) c))))))
        (vector-set! a (+ (* i m) c) (/ s (vector-ref b (+ (* i m) i)))))))
  ;; A <- A L^-T: the same along each row
  (do ((r 0 (+ r 1))) ((= r m))
    (do ((i 0 (+ i 1))) ((= i m))
      (let ((s (vector-ref a (+ (* r m) i))))
        (do ((l 0 (+ l 1))) ((= l i))
          (set! s (- s (* (vector-ref b (+ (* i m) l)) (vector-ref a (+ (* r m) l))))))
        (vector-set! a (+ (* r m) i) (/ s (vector-ref b (+ (* i m) i)))))))
  ;; symmetric again against rounding, then C = W diag(EV) W'
  (do ((i 0 (+ i 1))) ((= i m))
    (do ((j 0 (+ j 1))) ((= j i))
      (let ((s (* 0.5 (+ (vector-ref a (+ (* i m) j)) (vector-ref a (+ (* j m) i))))))
        (vector-set! a (+ (* i m) j) s)
        (vector-set! a (+ (* j m) i) s))))
  (sym-eigen a v ev e m)
  ;; V <- L^-T W: back substitution up each column
  (do ((c 0 (+ c 1))) ((= c m))
    (do ((ii 0 (+ ii 1))) ((= ii m))
      (let ((i (- (- m 1) ii)))
        (let ((s (vector-ref v (+ (* i m) c))))
          (do ((l (+ i 1) (+ l 1))) ((>= l m))
            (set! s (- s (* (vector-ref b (+ (* l m) i)) (vector-ref v (+ (* l m) c))))))
          (vector-set! v (+ (* i m) c) (/ s (vector-ref b (+ (* i m) i))))))))
  0)

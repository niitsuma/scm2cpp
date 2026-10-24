;;;; Kernel PCA, scikit-learn's KernelPCA written out in the subset: the
;;;; kernel matrix, centred in feature space (KernelCenterer), its
;;;; largest eigenpairs, and svd_flip's signs.  Three routes to the
;;;; eigenpairs: kpca-top-dense (sym-eigen-top, LAPACK's dsyevr under
;;;; --blas, scikit-learn's dense solver), kpca-top-subspace (subspace
;;;; iteration whose product is a dgemm, for a few pairs of a large
;;;; matrix, where scikit-learn takes ARPACK), and kpca-linear (the
;;;; linear kernel through Xc'Xc, p x p, instead of the n x n matrix).
;;;;
;;;; The kernels are those of scikit-learn's pairwise_kernels, over the
;;;; product G = X Y' (a dgemm under --blas, dsyrk for K(X, X)):
;;;;   0 linear   G
;;;;   1 rbf      exp(-gamma |x - y|^2), |x - y|^2 = |x|^2 + |y|^2 - 2 G
;;;;   2 poly     (gamma G + coef0)^degree
;;;;   3 sigmoid  tanh(gamma G + coef0), as 1 - 2 / (exp(2 z) + 1)
;;;;   4 cosine   G / (|x| |y|), a zero row giving zero
;;;; Centring: Kc = K - 1 m' - m 1' + mean(m) for m the column means;
;;;; a new block K(Y, X) is centred by its own row means and the same m.
;;;;

(include "sym-eigen.scm")

;; |x_i|^2 for the n rows of X (n x p)
(define (kpca-row-norms x s n p)
  (do ((i 0 (+ i 1))) ((= i n))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j)) (vector-ref x (+ (* i p) j))))))
      (vector-set! s i acc)))
  0)

;; G (na x nb) holds X Y' on entry and the kernel on exit; SA and SB are
;; the squared row norms of X and Y
(define (kpca-apply g sa sb kind gamma degree coef0 na nb)
  (do ((i 0 (+ i 1))) ((= i na))
    (do ((j 0 (+ j 1))) ((= j nb))
      (let ((q (vector-ref g (+ (* i nb) j))))
        (vector-set! g (+ (* i nb) j)
                     (if (= kind 1)
                         (let ((d (- (+ (vector-ref sa i) (vector-ref sb j)) (* 2.0 q))))
                           (exp (* (- 0.0 gamma) (if (< d 0.0) 0.0 d))))
                         (if (= kind 2)
                             (expt (+ (* gamma q) coef0) (* 1.0 degree))
                             (if (= kind 3)
                                 (- 1.0 (/ 2.0 (+ (exp (* 2.0 (+ (* gamma q) coef0))) 1.0)))
                                 (if (= kind 4)
                                     (let ((r (* (sqrt (vector-ref sa i)) (sqrt (vector-ref sb j)))))
                                       (if (> r 0.0) (/ q r) 0.0))
                                     q))))))))
  0)

;; K = kernel(X, Y) for X (na x p) and Y (nb x p)
(define (kpca-kernel x y k kind gamma degree coef0 na nb p)
  (let ((sa (make-vector na 0.0))
        (sb (make-vector nb 0.0)))
    (with-arrays ((x (na p)) (y (nb p)) (k (na nb)))
      (array-set! k (matmul x (transpose y))))
    (kpca-row-norms x sa na p)
    (kpca-row-norms y sb nb p)
    (kpca-apply k sa sb kind gamma degree coef0 na nb)
    0))

;; K = kernel(X, X), the product by its symmetric rank-k form
(define (kpca-kernel-self x k kind gamma degree coef0 n p)
  (let ((s (make-vector n 0.0)))
    (with-arrays ((x (n p)) (k (n n)))
      (array-set! k (matmul x (transpose x))))
    (kpca-row-norms x s n p)
    (kpca-apply k s s kind gamma degree coef0 n n)
    0))

;; Centre K (n x n) in place; M gets its column means, the last entry
;; M[n] their mean
(define (kpca-centre k m n)
  (let ((all 0.0))
    (do ((j 0 (+ j 1))) ((= j n))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i n)) (set! acc (+ acc (vector-ref k (+ (* i n) j)))))
        (vector-set! m j (/ acc (exact->inexact n)))
        (set! all (+ all (/ acc (exact->inexact n))))))
    (vector-set! m n (/ all (exact->inexact n)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j n))
        (vector-set! k (+ (* i n) j)
                     (+ (- (- (vector-ref k (+ (* i n) j)) (vector-ref m i)) (vector-ref m j))
                        (vector-ref m n)))))
    0))

;; Centre a block K (nb x n) against the fitted M from kpca-centre
(define (kpca-centre-new k m nb n)
  (do ((i 0 (+ i 1))) ((= i nb))
    (let ((acc 0.0))
      (do ((j 0 (+ j 1))) ((= j n)) (set! acc (+ acc (vector-ref k (+ (* i n) j)))))
      (let ((r (/ acc (exact->inexact n))))
        (do ((j 0 (+ j 1))) ((= j n))
          (vector-set! k (+ (* i n) j)
                       (+ (- (- (vector-ref k (+ (* i n) j)) r) (vector-ref m j)) (vector-ref m n)))))))
  0)

;; Every column of VECS (n x C) signed so that its entry of largest
;; magnitude is positive (svd_flip on u).  The values stay as found:
;; the caller judges the negative ones (_check_psd_eigenvalues)
(define (kpca-flip vecs vals n c)
  (do ((r 0 (+ r 1))) ((= r c))
    (let ((big 0) (bv -1.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (let ((a (vector-ref vecs (+ (* i c) r))))
          (let ((aa (if (< a 0.0) (- 0.0 a) a)))
            (if (> aa bv) (begin (set! bv aa) (set! big i)) 0))))
      (if (< (vector-ref vecs (+ (* big c) r)) 0.0)
          (do ((i 0 (+ i 1))) ((= i n))
            (vector-set! vecs (+ (* i c) r) (- 0.0 (vector-ref vecs (+ (* i c) r)))))
          0)))
  0)

;; The C largest eigenpairs of the centred K (n x n, destroyed), as
;; scikit-learn's dense solver takes them: VALS decreasing, VECS (n x C)
(define (kpca-top-dense k vecs vals n c)
  (let ((e (make-vector n 0.0)))
    (sym-eigen-top k vecs vals e n c)
    (kpca-flip vecs vals n c)
    0))

;; Y (n x b) made orthonormal in place by Cholesky QR: G = Y'Y = L L',
;; Y <- Y L^-T.  0 when a pivot falls under 1e-12 of its diagonal (the
;; columns have lost rank), else 1
(define (kpca-orth y g n b)
  (let ((ok 1))
    (with-arrays ((y (n b)) (g (b b)))
      (array-set! g (matmul (transpose y) y)))
    (do ((j 0 (+ j 1))) ((= j b))
      (let ((d (vector-ref g (+ (* j b) j)))
            (d0 (vector-ref g (+ (* j b) j))))
        (do ((l 0 (+ l 1))) ((= l j))
          (set! d (- d (* (vector-ref g (+ (* j b) l)) (vector-ref g (+ (* j b) l))))))
        (if (> d (* 1e-12 d0))
            (vector-set! g (+ (* j b) j) (sqrt d))
            (begin (set! ok 0) (vector-set! g (+ (* j b) j) 1.0)))
        (do ((i (+ j 1) (+ i 1))) ((>= i b))
          (let ((s (vector-ref g (+ (* i b) j))))
            (do ((l 0 (+ l 1))) ((= l j))
              (set! s (- s (* (vector-ref g (+ (* i b) l)) (vector-ref g (+ (* j b) l))))))
            (vector-set! g (+ (* i b) j) (/ s (vector-ref g (+ (* j b) j))))))))
    ;; each row x of the result solves x L' = y
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((j 0 (+ j 1))) ((= j b))
        (let ((s (vector-ref y (+ (* i b) j))))
          (do ((l 0 (+ l 1))) ((= l j))
            (set! s (- s (* (vector-ref y (+ (* i b) l)) (vector-ref g (+ (* j b) l))))))
          (vector-set! y (+ (* i b) j) (/ s (vector-ref g (+ (* j b) j)))))))
    ok))

;; The C largest eigenpairs of the centred K (n x n, kept) by subspace
;; iteration on B >= C columns, started from Q (n x B, overwritten):
;; each step Y = K Q, the Rayleigh-Ritz pairs of Q'Y, U = Q W and
;; K U = Y W; done when every one of the C residuals |K u - theta u| is
;; at most TOL times the largest theta, else Q <- K U orthonormalised
;; (twice).  The product is a dgemm under --blas, where ARPACK's
;; Lanczos multiplies by one vector at a time.  Returns the steps taken,
;; or -1 when MAXIT steps did not converge or the basis lost rank -- the
;; caller then takes kpca-top-dense.
(define (kpca-top-subspace k q vecs vals n b c tol maxit)
  (let ((y (make-vector (* n b) 0.0))
        (u (make-vector (* n b) 0.0))
        (ku (make-vector (* n b) 0.0))
        (t (make-vector (* b b) 0.0))
        (wv (make-vector (* b b) 0.0))
        (ws (make-vector (* b b) 0.0))
        (g (make-vector (* b b) 0.0))
        (th (make-vector b 0.0))
        (e (make-vector b 0.0))
        (ord (make-vector b 0))
        (status 0)
        (steps 0))
    (if (= (+ (kpca-orth q g n b) (kpca-orth q g n b)) 2) 0 (set! status -1))
    (do ((it 0 (+ it 1))) ((not (= status 0)))
      (with-arrays ((k (n n)) (q (n b)) (y (n b)) (t (b b)))
        (array-set! y (matmul k q))
        (array-set! t (matmul (transpose q) y)))
      (do ((i 0 (+ i 1))) ((= i b))
        (do ((j 0 (+ j 1))) ((= j i))
          (let ((s (* 0.5 (+ (vector-ref t (+ (* i b) j)) (vector-ref t (+ (* j b) i))))))
            (vector-set! t (+ (* i b) j) s)
            (vector-set! t (+ (* j b) i) s))))
      (sym-eigen t wv th e b)
      (eig-order th ord b)
      (do ((i 0 (+ i 1))) ((= i b))
        (do ((r 0 (+ r 1))) ((= r b))
          (vector-set! ws (+ (* i b) r) (vector-ref wv (+ (* i b) (vector-ref ord r))))))
      (with-arrays ((q (n b)) (y (n b)) (ws (b b)) (u (n b)) (ku (n b)))
        (array-set! u (matmul q ws))
        (array-set! ku (matmul y ws)))
      (let ((worst 0.0)
            (top (vector-ref th (vector-ref ord 0))))
        (do ((r 0 (+ r 1))) ((= r c))
          (let ((acc 0.0) (lam (vector-ref th (vector-ref ord r))))
            (do ((i 0 (+ i 1))) ((= i n))
              (let ((d (- (vector-ref ku (+ (* i b) r)) (* lam (vector-ref u (+ (* i b) r))))))
                (set! acc (+ acc (* d d)))))
            (if (> acc worst) (set! worst acc) 0)))
        (set! steps (+ it 1))
        (if (<= (sqrt worst) (* tol (if (< top 0.0) (- 0.0 top) top)))
            (begin
              (do ((r 0 (+ r 1))) ((= r c))
                (vector-set! vals r (vector-ref th (vector-ref ord r)))
                (do ((i 0 (+ i 1))) ((= i n))
                  (vector-set! vecs (+ (* i c) r) (vector-ref u (+ (* i b) r)))))
              (kpca-flip vecs vals n c)
              (set! status 1))
            (if (>= (+ it 1) maxit)
                (set! status -1)
                (begin
                  (do ((s 0 (+ s 1))) ((= s (* n b))) (vector-set! q s (vector-ref ku s)))
                  (if (= (+ (kpca-orth q g n b) (kpca-orth q g n b)) 2) 0 (set! status -1)))))))
    (if (= status 1) steps -1)))

;; The linear kernel through the p x p side: G (p x p) is Xc'Xc,
;; destroyed.  Its C largest eigenpairs are those of Xc Xc' (C <= p),
;; with the vectors Xc v / sqrt(lam) -- O(n p^2) where the n x n kernel
;; is O(n^2 p + n^3).  XM is the column means of X (zero when X is
;; already centred); VECS is n x C.
(define (kpca-linear x xm g vecs vals n p c)
  (let ((e (make-vector p 0.0))
        (v (make-vector (* p c) 0.0))
        (s (make-vector c 0.0)))
    (sym-eigen-top g v vals e p c)
    (with-arrays ((x (n p)) (v (p c)) (vecs (n c)))
      (array-set! vecs (matmul x v)))
    (do ((r 0 (+ r 1))) ((= r c))
      (let ((acc 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (set! acc (+ acc (* (vector-ref xm j) (vector-ref v (+ (* j c) r))))))
        (vector-set! s r acc)))
    (do ((i 0 (+ i 1))) ((= i n))
      (do ((r 0 (+ r 1))) ((= r c))
        (let ((lam (vector-ref vals r)))
          (vector-set! vecs (+ (* i c) r)
                       (if (> lam 0.0)
                           (/ (- (vector-ref vecs (+ (* i c) r)) (vector-ref s r)) (sqrt lam))
                           0.0)))))
    (kpca-flip vecs vals n c)
    0))

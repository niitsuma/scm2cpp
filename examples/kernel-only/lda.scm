;;;; Linear discriminant analysis over the Gram matrix: what scikit-learn's
;;;; LinearDiscriminantAnalysis forms from the n x p design, formed from
;;;; X'X (a dsyrk under --blas) and the class means instead.
;;;;
;;;; The within-class covariance (empirical priors) is
;;;;   Sw = (X'X - sum_k n_k mu_k mu_k') / n,
;;;; the total one St = (X'X - n xbar xbar') / n.  The "svd" solver takes
;;;; the SVD of Xs = Xc D^-1 / sqrt(n), Xc the rows less their class
;;;; means and D = diag(std) their deviations; Xs'Xs = D^-1 Sw D^-1, so
;;;; its right singular vectors and values are the eigenvectors and the
;;;; square roots of the eigenvalues of that p x p matrix (LAPACK's
;;;; dsyevd under --blas), with no pass over the n rows but the product.
;;;; The "eigen" solver's Sb v = lam Sw v is sym-eigen-gen (dsygvd).
;;;; What follows those -- the second, k x rank SVD, the coefficients --
;;;; is small and stays with the caller.
;;;;

(include "sym-eigen.scm")

;; MEANS (k x p) gets each class's mean and COUNTS (k) its rows, LAB
;; holding the class index 0..k-1 of every row; G (p x p) gets X'X
(define (lda-moments x lab g means counts n p k)
  (do ((q 0 (+ q 1))) ((= q (* k p))) (vector-set! means q 0.0))
  (do ((c 0 (+ c 1))) ((= c k)) (vector-set! counts c 0.0))
  (do ((i 0 (+ i 1))) ((= i n))
    (let ((c (vector-ref lab i)))
      (vector-set! counts c (+ (vector-ref counts c) 1.0))
      (do ((j 0 (+ j 1))) ((= j p))
        (vector-set! means (+ (* c p) j)
                     (+ (vector-ref means (+ (* c p) j)) (vector-ref x (+ (* i p) j)))))))
  (do ((c 0 (+ c 1))) ((= c k))
    (do ((j 0 (+ j 1))) ((= j p))
      (if (> (vector-ref counts c) 0.0)
          (vector-set! means (+ (* c p) j) (/ (vector-ref means (+ (* c p) j)) (vector-ref counts c)))
          0)))
  (with-arrays ((x (n p)) (g (p p)))
    (array-set! g (matmul (transpose x) x)))
  0)

;; G (p x p) from lda-moments becomes Sw, the within-class covariance
(define (lda-within g means counts n p k)
  (do ((a 0 (+ a 1))) ((= a p))
    (do ((b 0 (+ b 1))) ((= b p))
      (let ((acc (vector-ref g (+ (* a p) b))))
        (do ((c 0 (+ c 1))) ((= c k))
          (set! acc (- acc (* (vector-ref counts c)
                              (* (vector-ref means (+ (* c p) a)) (vector-ref means (+ (* c p) b)))))))
        (vector-set! g (+ (* a p) b) (/ acc (* 1.0 n))))))
  0)

;; The svd solver's first SVD from SW (p x p, kept): STD gets sqrt of
;; its diagonal (1 where that is 0), V (p x p) the right singular
;; vectors of Xs as columns and S the singular values, both by
;; decreasing value (negative eigenvalues, rounding, give 0)
(define (lda-svd-first sw std v s p)
  (let ((mm (make-vector (* p p) 0.0))
        (vv (make-vector (* p p) 0.0))
        (ev (make-vector p 0.0))
        (e (make-vector p 0.0))
        (ord (make-vector p 0)))
    (do ((j 0 (+ j 1))) ((= j p))
      (let ((d (vector-ref sw (+ (* j p) j))))
        (vector-set! std j (if (> d 0.0) (sqrt d) 1.0))))
    (do ((a 0 (+ a 1))) ((= a p))
      (do ((b 0 (+ b 1))) ((= b p))
        (vector-set! mm (+ (* a p) b)
                     (/ (vector-ref sw (+ (* a p) b)) (* (vector-ref std a) (vector-ref std b))))))
    (sym-eigen mm vv ev e p)
    (eig-order ev ord p)
    (do ((r 0 (+ r 1))) ((= r p))
      (let ((col (vector-ref ord r)))
        (vector-set! s r (if (> (vector-ref ev col) 0.0) (sqrt (vector-ref ev col)) 0.0))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! v (+ (* j p) r) (vector-ref vv (+ (* j p) col))))))
    0))

;; The eigen solver: Sb v = lam Sw v for Sb = St - Sw, SB and SW (p x p)
;; destroyed; V the vectors (V'SwV = I) and EV the values, both by
;; decreasing value
(define (lda-eigen sb sw v ev p)
  (let ((vv (make-vector (* p p) 0.0))
        (w (make-vector p 0.0))
        (e (make-vector p 0.0))
        (ord (make-vector p 0)))
    (sym-eigen-gen sb sw vv w e p)
    (eig-order w ord p)
    (do ((r 0 (+ r 1))) ((= r p))
      (let ((col (vector-ref ord r)))
        (vector-set! ev r (vector-ref w col))
        (do ((j 0 (+ j 1))) ((= j p))
          (vector-set! v (+ (* j p) r) (vector-ref vv (+ (* j p) col))))))
    0))

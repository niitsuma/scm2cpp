;;;; The two products the Gram-route estimators start from, on their own:
;;;; G = X'X and C = X'Y for X n rows of p and Y n rows of q (--blas
;;;; dsyrk and dgemm, --cublas on the device).  The package's wrappers
;;;; (LassoLarsIC, LarsCV, LassoLarsCV, Lars, LassoLars) call the --cublas
;;;; build when a device answers and the products are large, and form
;;;; them with numpy otherwise.
;;;;

(define (gram-xx x g n p)
  (with-arrays ((x (n p)) (g (p p)))
    (array-set! g (matmul (transpose x) x)))
  0)

(define (gram-xy x y c n p q)
  (with-arrays ((x (n p)) (y (n q)) (c (p q)))
    (array-set! c (matmul (transpose x) y)))
  0)

;; A W = B for A (m x m) symmetric positive definite, destroyed, and B
;; (m x q) overwritten by W: A = L L' (Cholesky), then the two triangular
;; solves.  Returns 0, or j + 1 when the jth pivot is not positive (A is
;; not positive definite; B is then unspecified).  Under --blas the call
;; is LAPACK's dposv, which numpy's solve and Cholesky reach as well.
(define (spd-solve a b m q)
  (let ((info 0))
    (do ((j 0 (+ j 1))) ((= j m))
      (let ((d (vector-ref a (+ (* j m) j))))
        (do ((l 0 (+ l 1))) ((= l j))
          (set! d (- d (* (vector-ref a (+ (* j m) l)) (vector-ref a (+ (* j m) l))))))
        (if (> d 0.0)
            (vector-set! a (+ (* j m) j) (sqrt d))
            (begin (if (= info 0) (set! info (+ j 1)) 0) (vector-set! a (+ (* j m) j) 1.0)))
        (do ((i (+ j 1) (+ i 1))) ((>= i m))
          (let ((s (vector-ref a (+ (* i m) j))))
            (do ((l 0 (+ l 1))) ((= l j))
              (set! s (- s (* (vector-ref a (+ (* i m) l)) (vector-ref a (+ (* j m) l))))))
            (vector-set! a (+ (* i m) j) (/ s (vector-ref a (+ (* j m) j))))))))
    ;; L Y = B, then L' W = Y, column by column of B
    (do ((c 0 (+ c 1))) ((= c q))
      (do ((i 0 (+ i 1))) ((= i m))
        (let ((s (vector-ref b (+ (* i q) c))))
          (do ((l 0 (+ l 1))) ((= l i))
            (set! s (- s (* (vector-ref a (+ (* i m) l)) (vector-ref b (+ (* l q) c))))))
          (vector-set! b (+ (* i q) c) (/ s (vector-ref a (+ (* i m) i))))))
      (do ((ii 0 (+ ii 1))) ((= ii m))
        (let ((i (- (- m 1) ii)))
          (let ((s (vector-ref b (+ (* i q) c))))
            (do ((l (+ i 1) (+ l 1))) ((>= l m))
              (set! s (- s (* (vector-ref a (+ (* l m) i)) (vector-ref b (+ (* l q) c))))))
            (vector-set! b (+ (* i q) c) (/ s (vector-ref a (+ (* i m) i))))))))
    info))

;; spd-solve with the reciprocal condition number of A in the 1-norm:
;; A W = B as spd-solve has it, then 1 / (|A|_1 |A^-1|_1), or -1.0 when
;; A is not positive definite.  Here A^-1 is formed from the factor
;; (exact, m^3); under --blas the call is dposv and LAPACK's dpocon,
;; whose estimate scipy's solve warns by (O(m^2), within a small factor
;; of the exact value).
(define (gram-abs x) (if (< x 0.0) (- 0.0 x) x))

(define (spd-solve-rcond a b m q)
  (let ((anorm 0.0) (inorm 0.0) (x (make-vector m 0.0)))
    (do ((c 0 (+ c 1))) ((= c m))
      (let ((acc 0.0))
        (do ((i 0 (+ i 1))) ((= i m))
          (set! acc (+ acc (gram-abs (vector-ref a (+ (* i m) c))))))
        (if (> acc anorm) (set! anorm acc) 0)))
    (if (= (spd-solve a b m q) 0)
        (begin
          ;; column c of A^-1 = L'^-1 L^-1 e_c, L in A's lower triangle
          (do ((c 0 (+ c 1))) ((= c m))
            (do ((i 0 (+ i 1))) ((= i m))
              (let ((s (if (= i c) 1.0 0.0)))
                (do ((l 0 (+ l 1))) ((= l i))
                  (set! s (- s (* (vector-ref a (+ (* i m) l)) (vector-ref x l)))))
                (vector-set! x i (/ s (vector-ref a (+ (* i m) i))))))
            (do ((ii 0 (+ ii 1))) ((= ii m))
              (let ((i (- (- m 1) ii)))
                (let ((s (vector-ref x i)))
                  (do ((l (+ i 1) (+ l 1))) ((>= l m))
                    (set! s (- s (* (vector-ref a (+ (* l m) i)) (vector-ref x l)))))
                  (vector-set! x i (/ s (vector-ref a (+ (* i m) i)))))))
            (let ((acc 0.0))
              (do ((i 0 (+ i 1))) ((= i m))
                (set! acc (+ acc (gram-abs (vector-ref x i)))))
              (if (> acc inorm) (set! inorm acc) 0)))
          (/ 1.0 (* anorm inorm)))
        -1.0)))

;; (G + ALPHA I) W = C for G (m x m) kept and C (m x q) overwritten by
;; W: the ridge solve the Gram-route fits call.  Through spd-solve, so a
;; caller from outside (the package) reaches dposv under --blas: the
;; lowering replaces calls, not the definition a C entry point exports.
;; Returns spd-solve's info.
(define (gram-ridge-solve g c alpha m q)
  (let ((a (make-vector (* m m) 0.0)))
    (do ((s 0 (+ s 1))) ((= s (* m m))) (vector-set! a s (vector-ref g s)))
    (do ((j 0 (+ j 1))) ((= j m))
      (vector-set! a (+ (* j m) j) (+ (vector-ref a (+ (* j m) j)) alpha)))
    (spd-solve a c m q)))

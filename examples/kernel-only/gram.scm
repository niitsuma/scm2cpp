;;;; The two products the Gram-route estimators start from, on their own:
;;;; G = X'X and C = X'Y for X n rows of p and Y n rows of q (--blas
;;;; dsyrk and dgemm, --cublas on the device).  The package's wrappers
;;;; (LassoLarsIC, LarsCV, LassoLarsCV, Lars, LassoLars) call the --cublas
;;;; build when a device answers and the products are large, and form
;;;; them with numpy otherwise.
;;;;
;;;;[ja] Gram 経路の推定器が最初に作る 2 つの積 G = X'X と C = X'Y だけを
;;;;[ja] 取り出したもの(--blas で dsyrk / dgemm、--cublas でデバイス上)。

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
;;[ja] 正定値の A について A W = B を解く(Cholesky と 2 回の三角解法)。--blas では dposv。
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

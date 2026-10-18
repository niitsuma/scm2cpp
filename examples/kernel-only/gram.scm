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

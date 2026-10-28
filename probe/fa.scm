;; fa.scm on twelve rows of four features, two factors: the covariance
;; formed here by loops, then fa-fit from unit noise variances.  Prints
;; the iterations, the noise variances, the column sums of the squared
;; components (which no eigenvector's sign changes) and the last
;; log-likelihood.  Plain the eigenproblem is sym-eigen.scm's; under
;; --blas it is LAPACK's dsyevr.
(include "../examples/kernel-only/fa.scm")

(define (show v m)
  (do ((j 0 (+ j 1))) ((= j m))
    (display (vector-ref v j)) (display " "))
  (newline))

(define (main)
  (let ((x0 (vector 0.31 -0.72 1.05 0.4  0.18 -0.44 0.93 0.1  0.67 -1.21 -0.09 -0.3
                    0.52 1.38 -0.35 0.7  -0.81 -0.27 0.44 -0.6  1.12 0.05 -0.63 0.9
                    -0.38 0.91 0.27 -0.2  0.74 -0.16 1.41 0.5  -1.02 0.58 -0.47 -0.8
                    0.29 1.17 0.83 0.6  0.95 -0.66 0.12 0.3  -0.57 0.39 -1.14 -0.4))
        (n 12) (p 4) (k 2) (maxit 200))
    (let ((x (make-vector (* n p) 0.0))
          (xm (make-vector p 0.0))
          (c (make-vector (* p p) 0.0))
          (var (make-vector p 0.0))
          (psi (make-vector p 1.0))
          (w (make-vector (* k p) 0.0))
          (ll (make-vector maxit 0.0)))
      (do ((s 0 (+ s 1))) ((= s (* n p))) (vector-set! x s (vector-ref x0 s)))
      (do ((j 0 (+ j 1))) ((= j p))
        (do ((i 0 (+ i 1))) ((= i n))
          (vector-set! xm j (+ (vector-ref xm j) (/ (vector-ref x (+ (* i p) j)) (* 1.0 n))))))
      (do ((a 0 (+ a 1))) ((= a p))
        (do ((b 0 (+ b 1))) ((= b p))
          (let ((acc 0.0))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc (* (- (vector-ref x (+ (* i p) a)) (vector-ref xm a))
                                  (- (vector-ref x (+ (* i p) b)) (vector-ref xm b))))))
            (vector-set! c (+ (* a p) b) (/ acc (* 1.0 n))))))
      (do ((j 0 (+ j 1))) ((= j p)) (vector-set! var j (vector-ref c (+ (* j p) j))))
      (let ((it (fa-fit c var psi w ll n p k maxit 1e-2))
            (cs (make-vector p 0.0)))
        (display it) (newline)
        (show psi p)
        (do ((j 0 (+ j 1))) ((= j p))
          (do ((r 0 (+ r 1))) ((= r k))
            (vector-set! cs j (+ (vector-ref cs j) (* (vector-ref w (+ (* r p) j)) (vector-ref w (+ (* r p) j)))))))
        (show cs p)
        (display (vector-ref ll (- (min it maxit) 1))) (newline)
        0))))

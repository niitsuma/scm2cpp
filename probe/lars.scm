;; lars.scm on the Gram and correlations of a small correlated design
;; (computed here from five centred rows of four features): method
;; "lar" to the end and "lasso" at alpha 0.05, then the whole "lasso"
;; path recorded (lars_path(return_path=True)); translated plainly, the
;; oracle runs the same program.  Prints the step counts and the
;; coefficients, then the path's alphas and its rows.  drop-case is a
;; second design (six rows) whose "lasso" path loses a variable at its
;; fourth step: the path's rows, then the number of entries that are
;; neither zero nor larger than 1e-12 -- a coefficient that leaves the
;; path must be exactly zero at that knot, so the count is 0
;; (run-tests.sh looks for the line "residue 0").
;;[ja] drop-case は 2 つ目の計画行列(6 行)で、"lasso" の経路が 4 段目で変数を
;;[ja] 1 つ手放す。経路の行と、0 でも 1e-12 超でもない要素の数を表示する。
;;[ja] 経路から抜ける係数はその節点で厳密に 0 なので、数は 0
;;[ja] (run-tests.sh が "residue 0" の行を確かめる)。
(include "../examples/kernel-only/lars.scm")

(define (drop-case)
  (let ((n 6) (p 4)
        (x (vector 1.0 0.75 0.5 -0.5   0.25 -0.5 0.0 -1.0   -0.5 -0.5 0.25 -1.0
                   -0.5 -1.0 -0.75 0.0   -0.5 -0.75 0.5 -1.0   -0.75 1.0 1.0 -0.75))
        (y (vector 1.25 -1.75 -0.25 2.0 -0.25 0.75))
        (g (make-vector 16 0.0))
        (cov (make-vector 4 0.0))
        (coef (make-vector 4 0.0))
        (tiny 0))
   (let ((path (make-vector (* 9 p) 0.0)) (alphas (make-vector 9 0.0)))
     (do ((a 0 (+ a 1))) ((= a p))
       (let ((acc 0.0))
         (do ((i 0 (+ i 1))) ((= i n))
           (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref y i)))))
         (vector-set! cov a acc))
       (do ((b 0 (+ b 1))) ((= b p))
         (let ((acc 0.0))
           (do ((i 0 (+ i 1))) ((= i n))
             (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref x (+ (* i p) b))))))
           (vector-set! g (+ (* a p) b) acc))))
     (let ((it (lars g cov coef path alphas 1 6.0 0.0 1 8 2.220446049250313e-16 p)))
       (display it) (newline)
       (do ((s 0 (+ s 1))) ((> s it))
         (do ((j 0 (+ j 1))) ((= j p))
           (let ((c (vector-ref path (+ (* s p) j))))
             (if (and (not (= c 0.0)) (< (abs c) 1e-12)) (set! tiny (+ tiny 1)) 0)
             (display c) (display " ")))
         (newline))
       (display "residue ") (display tiny) (newline)))
   0))

(define (main)
  (let ((n 5) (p 4)
        (x (vector 1.0 0.75 0.5 -0.5   -1.0 -0.5 -1.0 0.5   0.5 0.25 1.0 -1.0
                   -0.5 -0.75 -0.25 0.75   0.0 0.25 -0.25 0.25))
        (y (vector 2.0 -1.75 1.25 -1.5 0.0))
        (g (make-vector 16 0.0))
        (cov (make-vector 4 0.0))
        (coef (make-vector 4 0.0)))
   ;; the path's buffers runtime-sized: 9 rows for at most 8 steps
   (let ((path (make-vector (* 9 p) 0.0)) (alphas (make-vector 9 0.0)))
    (do ((round 0 (+ round 1))) ((= round 3))
      (do ((a 0 (+ a 1))) ((= a p))
        (let ((acc 0.0))
          (do ((i 0 (+ i 1))) ((= i n))
            (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref y i)))))
          (vector-set! cov a acc))
        (do ((b 0 (+ b 1))) ((= b p))
          (let ((acc 0.0))
            (do ((i 0 (+ i 1))) ((= i n))
              (set! acc (+ acc (* (vector-ref x (+ (* i p) a)) (vector-ref x (+ (* i p) b))))))
            (vector-set! g (+ (* a p) b) acc))))
      (if (< round 2)
          (let ((it (lars g cov coef path alphas 0 5.0 (if (= round 0) 0.0 0.05) round 500
                          2.220446049250313e-16 p)))
            (display it) (display " ")
            (do ((j 0 (+ j 1))) ((= j p))
              (display (vector-ref coef j)) (display " "))
            (newline))
          (let ((it (lars g cov coef path alphas 1 5.0 0.0 1 8 2.220446049250313e-16 p)))
            (display it) (newline)
            (do ((s 0 (+ s 1))) ((> s it))
              (display (vector-ref alphas s)) (display " ")
              (do ((j 0 (+ j 1))) ((= j p))
                (display (vector-ref path (+ (* s p) j))) (display " "))
              (newline)))))
    (drop-case)
    0)))

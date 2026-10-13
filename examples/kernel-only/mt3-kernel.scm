;;;; The multi-task lasso of mt-kernel.scm with the tasks laid out as a
;;;; grid: NB blocks of NT tasks each, so the coefficients are a rank-3
;;;; array W (p x nb x nt), the residual a rank-3 array R (n x nb x nt),
;;;; and everything is stored the numpy way, C order, X n rows of p.
;;;; A feature's whole nb x nt slab of W enters or leaves at once,
;;;; under the L2 norm of its unpenalized optimum, exactly as mt-kernel
;;;; treats a row; the mathematics is multi-task with nb*nt tasks, the
;;;; rank is in the layout alone -- which is what makes this the probe
;;;; of the derivation at rank 3: the residual of task (b,t) is the
;;;; fiber R[:,b,t], updated down its length by a column of X, and
;;;; --derive must memoise it as C[b,t,j] = X[:,j] . R[:,b,t], hoist
;;;; the Gram X'X, restore R -= X (W - W0) with W flattened to
;;;; p x (nb*nt), and guard it all by (if (< p n) ..).
;;;;
;;;;[ja] mt-kernel.scm の multi-task lasso で、タスクを nb ブロック x nt
;;;;[ja] タスクの格子に並べたもの。係数 W は p x nb x nt、残差 R は
;;;;[ja] n x nb x nt の 3 階配列で、全部 numpy の持ち方(C 順、X は n 行 p
;;;;[ja] 列)。特徴 j の nb x nt のスラブがまとめて出入りする(mt-kernel が
;;;;[ja] 行をまとめて扱うのと同じ)。数学は nb*nt タスクの multi-task
;;;;[ja] そのもので、階数は配置にしかない。それがこのファイルを「階数 3 の
;;;;[ja] 導出」の probe にしている: タスク (b,t) の残差は fiber R[:,b,t]、
;;;;[ja] X の列で長さ方向に更新され、--derive はそれをメモ
;;;;[ja] C[b,t,j] = X[:,j] . R[:,b,t] に置き換え、Gram X'X を外に出し、
;;;;[ja] W を p x (nb*nt) に平坦化して R -= X (W - W0) で復元し、全体を
;;;;[ja] (if (< p n) ..) で守らなければならない。

(include "soft-threshold.scm")

(define (mt3 x w resid xnorm lam1 lam2 iters n p nb nt)
  ;; The shapes, for --derive: rank 3 where the layout is rank 3.
  ;;[ja] --derive 用の形: 配置が 3 階のものは 3 階で宣言する。
  (with-arrays ((x (n p)) (w (p nb nt)) (resid (n nb nt)) (xnorm (p)))
  (let ((stop 0))
    (do ((sweep 0 (+ sweep 1))) ((or (= sweep iters) (= stop 1)))
      (let ((moved 0))
        (do ((j 0 (+ j 1))) ((= j p))
          (let ((gjj (vector-ref xnorm j))
                (nrm2 0.0))
            ;; the norm of the slab's unpenalized optimum, over (b,t)
            ;;[ja] スラブの無罰則最適値のノルム。(b,t) 全体で取る
            (do ((b 0 (+ b 1))) ((= b nb))
              (do ((t 0 (+ t 1))) ((= t nt))
                (let ((rho 0.0))
                  (do ((i 0 (+ i 1))) ((= i n))
                    (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                        (vector-ref resid (+ (* (+ (* i nb) b) nt) t))))))
                  (let ((z (+ rho (* gjj (vector-ref w (+ (* (+ (* j nb) b) nt) t))))))
                    (set! nrm2 (+ nrm2 (* z z)))))))
            (let ((nrm (sqrt nrm2))
                  (thr (* lam1 (* 1.0 n))))
              (let ((scale (if (> nrm thr)
                               (/ (- nrm thr)
                                  (* nrm (+ gjj (* lam2 (* 1.0 n)))))
                               0.0)))
                ;; the step, task by task; a task whose coefficient moved
                ;; updates its own fiber of the residual
                ;;[ja] タスクごとのステップ。係数が動いたタスクは自分の
                ;;[ja] fiber の残差を更新する
                (do ((b 0 (+ b 1))) ((= b nb))
                  (do ((t 0 (+ t 1))) ((= t nt))
                    (let ((old (vector-ref w (+ (* (+ (* j nb) b) nt) t)))
                          (rho 0.0))
                      (do ((i 0 (+ i 1))) ((= i n))
                        (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                            (vector-ref resid (+ (* (+ (* i nb) b) nt) t))))))
                      (let ((wnew (* scale (+ rho (* gjj old)))))
                        (vector-set! w (+ (* (+ (* j nb) b) nt) t) wnew)
                        (if (not (= wnew old))
                            (begin
                              (set! moved 1)
                              (do ((i 0 (+ i 1))) ((= i n))
                                (vector-set! resid (+ (* (+ (* i nb) b) nt) t)
                                             (- (vector-ref resid (+ (* (+ (* i nb) b) nt) t))
                                                (* (vector-ref x (+ (* i p) j))
                                                   (- wnew old))))))
                            #f)))))))))
        (if (= moved 0) (set! stop 1) 0)))))
  0)

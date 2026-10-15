;;;; The objectives lbfgs.scm minimises, behind its one entry lbfgs-fg:
;;;; KIND 0 is logistic-lbfgs.scm's (AUX: l2, multi, fit_intercept), 1
;;;; huber.scm's (AUX: epsilon, alpha, fit_intercept).
;;;; A program takes the L-BFGS fits by including this file.
;;;;
;;;;[ja] lbfgs.scm が最小化する目的関数を lbfgs-fg 1 つにまとめたもの。
;;;;[ja] KIND 0 はロジスティック回帰、1 は Huber 回帰。L-BFGS を使うプログラムはこのファイルを
;;;;[ja] include する。

(include "logistic-lbfgs.scm")
(include "huber.scm")
(include "lbfgs.scm")

(define (lbfgs-fg kind w g x y aux work n p k)
  (if (= kind 0)
      (logistic-fg w g x y work (vector-ref aux 0)
                   (if (= (vector-ref aux 1) 1.0) 1 0) (if (= (vector-ref aux 2) 1.0) 1 0) n p k)
      (huber-fg w g x y work (vector-ref aux 0) (vector-ref aux 1)
                (if (= (vector-ref aux 2) 1.0) 1 0) n p)))

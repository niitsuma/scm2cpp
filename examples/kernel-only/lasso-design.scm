;;;; The lasso path from the design matrix as numpy holds it: X is n
;;;; rows of p, x[i*p+j], C order, and nothing is prepared outside.
;;;; The kernel copies y into the residual and takes the column norms
;;;; itself, then runs the residual-form coordinate descent of
;;;; lasso-kernel.scm down the columns.  This is the kernel behind
;;;; DerivedLasso in python/scm2cpp-learn: with --derive the memo
;;;; c = X'r, the Gram X'X (one dsyrk under --blas) and the
;;;; (if (< p n) ..) guard are the translator's, and the Python side
;;;; hands over X and y as they are -- no transposed copy, no norms.
;;;;
;;;; RESID and XNORM are parameters only so that the caller owns the
;;;; buffers (the -M wrapper takes numpy arrays); they are filled here.
;;;; The rest -- LAMS, BETAS, ITERS, TOL -- is as in lasso-kernel.scm.
;;;; The value is the number of sweeps run, over the whole path.
;;;;
;;;;[ja] numpy が持つままの設計行列から lasso のパスを解くカーネル。
;;;;[ja] X は n 行 p 列で x[i*p+j](C 順)、外では何も準備しない。残差への
;;;;[ja] y の写しと列ノルムの計算もこの中で行い、そのあと lasso-kernel.scm
;;;;[ja] と同じ残差形の座標降下を「列を下る」向きで回す。これが
;;;;[ja] python/scm2cpp-learn の DerivedLasso の裏のカーネルで、--derive を
;;;;[ja] かけるとメモ c = X'r、Gram X'X(--blas なら dsyrk 1 回)、分岐
;;;;[ja] (if (< p n) ..) は翻訳器が出し、Python 側は X と y をそのまま渡す
;;;;[ja] だけになる(転置コピーもノルム計算もない)。
;;;;[ja]
;;;;[ja] RESID と XNORM が引数なのは、-M のラッパが numpy の配列を渡す都合で
;;;;[ja] 呼び出し側にバッファを持たせるため。中身はここで埋める。LAMS(罰則
;;;;[ja] の列)、BETAS(罰則ごとの解)、ITERS(掃引数の上限)、TOL(収束判定)
;;;;[ja] は lasso-kernel.scm と同じ。戻り値はパス全体で回した掃引の数。

(include "soft-threshold.scm")

;; x       the design, n rows of p (x[i*p+j]); read only
;; y       the observations, n
;; resid   the residual r = y - X beta, n; filled from y here, kept current
;; xnorm   the squared column norms, p; filled here
;; beta    the coefficients, p; the working state, warm-started along the path
;; lams    the penalties, largest first, nlam of them
;; betas   row l = the fit at lams[l], flat nlam x p
;; iters   at most this many sweeps per penalty
;; tol     a sweep whose largest coefficient move is <= tol ends the fit
;;         (0.0: the exact fixed point, a sweep that moved nothing)
;;[ja] x      設計行列。n 行 p 列、x[i*p+j]。読むだけ
;;[ja] y      観測値、長さ n
;;[ja] resid  残差 r = y - X beta、長さ n。ここで y から作り、以後つねに最新
;;[ja] xnorm  各列の二乗ノルム、長さ p。ここで計算する
;;[ja] beta   係数、長さ p。作業状態で、パスに沿って前の解から始める
;;[ja] lams   罰則の列(大きい順)、nlam 個
;;[ja] betas  行 l が lams[l] での解。平坦な nlam x p
;;[ja] iters  罰則 1 つあたりの掃引数の上限
;;[ja] tol    掃引中の係数の最大移動が tol 以下なら、その罰則の fit は終わり
;;[ja]        (0.0 なら「何も動かなかった掃引」= 厳密な不動点まで回す)
(define (lasso-design x y resid xnorm beta lams betas iters tol n p nlam)
  ;; swept counts the sweeps, the function's value (scikit-learn's n_iter_)
  ;;[ja] swept は掃引の数で、関数の値(scikit-learn の n_iter_)
  (let ((swept 0))
  ;; The shapes, for --derive: X is n rows of p, the rest are vectors or
  ;; the nlam x p table.  The declaration changes nothing in the plain
  ;; translation; it is what lets the derivation read x[i*p+j] as a
  ;; column of X.
  ;;[ja] --derive 用の形の宣言。X は n 行 p 列、他はベクタか nlam x p の表。
  ;;[ja] 素の翻訳には何の影響もなく、導出が x[i*p+j] を X の列として読む
  ;;[ja] ための情報。
  (with-arrays ((x (n p)) (y (n)) (resid (n)) (xnorm (p)) (beta (p))
                (lams (nlam)) (betas (nlam p)))
  ;; r = y: nothing has been fitted yet
  ;;[ja] 残差の初期値は y そのもの(まだ何も当てはめていない)
  (do ((i 0 (+ i 1))) ((= i n))
    (vector-set! resid i (vector-ref y i)))
  ;; xnorm[j] = sum_i x[i,j]^2: the denominator of every coordinate
  ;; step.  Under --derive this fill is folded into the diagonal of the
  ;; Gram matrix (the merge rule) and no longer runs in the Gram branch.
  ;;[ja] xnorm[j] = sum_i x[i,j]^2。各座標ステップの分母。--derive では
  ;;[ja] この計算は Gram 行列の対角に畳み込まれ(merge 規則)、Gram 側の
  ;;[ja] 分岐ではもう走らない。
  (do ((j 0 (+ j 1))) ((= j p))
    (let ((acc 0.0))
      (do ((i 0 (+ i 1))) ((= i n))
        (set! acc (+ acc (* (vector-ref x (+ (* i p) j))
                            (vector-ref x (+ (* i p) j))))))
      (vector-set! xnorm j acc)))
  ;; The path: one fit per penalty, each warm-started from the last.
  ;;[ja] パス: 罰則ごとに 1 つの fit。各 fit は前の解から始める。
  (do ((l 0 (+ l 1)))
      ((= l nlam))
    (let ((lam (vector-ref lams l)))
      (let ((stop 0))
        ;; Sweeps over the coordinates until none moved by more than tol,
        ;; or iters of them.
        ;;[ja] 座標を一巡する掃引を、どの座標も tol より大きく動かなく
        ;;[ja] なるまで(または iters 回まで)繰り返す。
        (do ((sweep 0 (+ sweep 1)))
            ((or (= sweep iters) (= stop 1)))
          (set! swept (+ swept 1))
          (let ((maxmove 0.0))
            (do ((j 0 (+ j 1)))
                ((= j p))
              ;; rho = x_j . r + xnorm[j] beta[j]: the unpenalized optimum
              ;; of coordinate j with the others held, times xnorm[j].
              ;; The dot product walks column j of X -- the loop --derive
              ;; replaces by a read of the memo c[j].
              ;;[ja] rho = x_j . r + xnorm[j] beta[j]: 他の座標を固定した
              ;;[ja] ときの座標 j の無罰則の最適値 × xnorm[j]。内積は X の
              ;;[ja] 列 j を下るループで、--derive はこれをメモ c[j] の読み
              ;;[ja] 1 回に置き換える。
              (let ((rho 0.0)
                    (old (vector-ref beta j)))
                (do ((i 0 (+ i 1)))
                    ((= i n))
                  (set! rho (+ rho (* (vector-ref x (+ (* i p) j))
                                      (vector-ref resid i)))))
                (set! rho (+ rho (* old (vector-ref xnorm j))))
                ;; Soft-threshold at lam * n (the objective is scaled by
                ;; 1/(2n), as scikit-learn's), then divide by the norm:
                ;; the new value of coordinate j.
                ;;[ja] lam * n で soft-threshold(目的関数は scikit-learn と
                ;;[ja] 同じく 1/(2n) 倍)し、ノルムで割る。これが座標 j の
                ;;[ja] 新しい値。
                (let ((bnew (/ (soft-threshold rho (* lam (* 1.0 n)))
                               (vector-ref xnorm j))))
                  (vector-set! beta j bnew)
                  ;; A coordinate that did not move leaves the residual
                  ;; as it is (most coordinates of a sparse solution);
                  ;; one that did moves r by -(bnew - old) x_j, down
                  ;; column j again.  --derive turns this update into
                  ;; c -= (bnew - old) G[:,j], O(p) instead of O(n).
                  ;; maxmove is |bnew - old| at its largest, kept with
                  ;; two comparisons (no abs or max in the subset).
                  ;;[ja] 動かなかった座標は残差をそのまま(疎な解では大半が
                  ;;[ja] これ)。動いた座標は r を -(bnew - old) x_j だけ
                  ;;[ja] 動かす(また列 j を下る)。--derive はこの更新を
                  ;;[ja] c -= (bnew - old) G[:,j] に変え、O(n) が O(p) に
                  ;;[ja] なる。maxmove は |bnew - old| の最大値で、subset に
                  ;;[ja] abs も max もないので比較 2 つで持つ。
                  (if (not (= bnew old))
                      (begin
                        (if (> (- bnew old) maxmove) (set! maxmove (- bnew old)) 0)
                        (if (> (- old bnew) maxmove) (set! maxmove (- old bnew)) 0)
                        (do ((i 0 (+ i 1)))
                            ((= i n))
                          (vector-set! resid i
                                       (- (vector-ref resid i)
                                          (* (vector-ref x (+ (* i p) j))
                                             (- bnew old))))))
                      #f))))
            (if (<= maxmove tol) (set! stop 1) 0))))
      ;; Row l of betas gets the fit at this penalty; beta carries on to
      ;; the next one as its warm start.
      ;;[ja] betas の行 l にこの罰則での解を写す。beta はそのまま次の罰則の
      ;;[ja] 初期値になる。
      (do ((j 0 (+ j 1)))
          ((= j p))
        (vector-set! betas (+ (* l p) j) (vector-ref beta j))))))
  swept))

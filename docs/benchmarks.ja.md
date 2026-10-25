# 推定器と scikit-learn の比較

*[English](benchmarks.md)* · [README](../README.ja.md)

推定器ごとの scikit-learn との比較です。アルゴリズム、部分集合での書き方、測り方、README の要約の元になった表を載せています。

## SVM と sklearn の比較

`examples/kernel-only/` に SVM のカーネルが 4 つあります。
`svm-liblinear.scm` は liblinear の L1-loss 線形 SVM ソルバをそのまま
書いたものです。掃引ごとの乱択順、shrinking、射影勾配による停止判定
を含む双対座標降下で、scikit-learn の `LinearSVC(loss="hinge",
dual=True)` が走らせるコードと同じです。`svm-kernel.scm` は同じ掃引を
固定順序・shrinking なしで書いたもので、`--derive` はこれを
`(if (< n p) ..)` の下でカーネル形(カーネル行列 `X X'` 上のメモ
`c = X w`)に変えます。`svm-dual.scm` はそのカーネル形を任意の
カーネル行列に対して手で書いたもので、非線形(RBF)の SVM も回せます。
`svm-smo.scm` は、`SVC` が走らせる libsvm の SMO ソルバをそのまま書いた
ものです。

測定は `bench/svm-compare.py`、1 コアです(i9-10900X、cuBLAS の列は
RTX 4090、sklearn 1.9.1、他のジョブで load average 約 4.5)。条件は
C = 1、切片なしです。線形のソルバはどれも同じ停止判定(射影勾配の幅
<= 1e-4)か、1,000 掃引で止めます。目的関数は主問題
`1/2 |w|^2 + C Σ max(0, 1 - y w.x)` です:

| n × p | `svm-liblinear.scm`(普通の翻訳) | `LinearSVC` | 倍率 | 目的関数(ours / sklearn) | `svm-kernel.scm --derive --cublas` |
|---|---|---|---|---|---|
| 5,000 × 200 | 0.369 s | 0.774 s | 2.1 倍 | 1541.06 / 1541.37 | 0.982 s(n > p: 書いたとおりの掃引) |
| 100,000 × 200 | 25.9 s | 48.7 s | 1.9 倍 | 34503.5 / 34506.9 | 29.6 s(同上) |
| 300 × 2,000 | 0.011 s | 0.026 s | 2.4 倍 | 0.08439 / 0.08430 | 0.003 s(カーネル形) |
| 2,000 × 20,000 | 0.965 s | 1.998 s | 2.1 倍 | 0.05411 / 0.05400 | 0.256 s(カーネル形) |

- **同じアルゴリズムなら sklearn より約 2 倍速く、目的関数も同じ
  ところまで下がります。** 差はアルゴリズムではなく実装から来て
  います。liblinear は密なデータでも各行を疎表現 `feature_node` の
  リストで歩きますが、翻訳したループは密で、`-O3 -march=native` で
  ベクトル化されます。このカーネルは普通に翻訳したもので、
  `--derive` は適用されません。1 ステップが扱う点が `index[s]`、
  つまり let で束縛した添字で、ループ座標ではないからです。
- **shrinking と乱択順はアルゴリズムの一部です。** `svm-kernel.scm`
  はどちらも持ちません。縦長のデータでは同じ回数の掃引が要り、
  しかも毎回すべての点を見るうえ、目的関数も悪いところで終わります
  (5,000 × 200 で 1548.32)。固定順序のまま shrinking だけ入れると
  さらに悪く、同じ点が毎回外されて収束が止まります。
- **横長のデータでは、導出したカーネル形が GPU で効きます。**
  2,000 × 20,000 で cuBLAS 版は `LinearSVC` の 7.8 倍です。CPU の BLAS
  版は効かず、1.049 s で、書いたとおりの掃引(0.721 s)より遅く
  なります。12 掃引で終わる問題では、n × n × p のカーネル行列を作る
  費用を回収できません。ガードは形しか見ておらず、掃引の回数を
  考えていないためです。

非線形(RBF、gamma = 1/p、C = 1。精度は新しい 2,000 行で測定。こちらは
numpy で K を作る時間を含む。load average 1.6〜3.7)。`svm-smo.scm` は libsvm の C-SVC ソルバを
そのまま書いたものです。WSS3 の作業集合選択、勾配の再構成つきの
shrinking、切片の計算を含みます。SVC と同じ問題を SVC と同じ tol 1e-3
で、カーネル行列全体の上で解きます(全行がキャッシュに入る libsvm に
相当)。そのため同じ K の上の `SVC(kernel='precomputed')` と比べます。
`svm-dual.scm` は `svm-kernel.scm` のカーネル形で、切片なし、shrinking
なし、tol 1e-4 です。

| n × p | `svm-smo.scm` | `SVC(kernel='precomputed')`(K 込み) | `SVC(kernel='rbf')` | 双対の目的関数(ours / SVC) | 反復回数(ours / SVC) | `svm-dual.scm` |
|---|---|---|---|---|---|---|
| 2,000 × 50 | 0.070 s | 0.078 s | 0.145 s | -1071.2597 / -1071.2597 | 2,291 / 2,274 | 4.71 s |
| 5,000 × 50 | 0.490 s | 0.561 s | 0.957 s | -2622.9261 / -2622.9261 | 5,741 / 5,755 | 38.2 s |
| 10,000 × 50 | 2.08 s | 2.55 s | 4.05 s | -5044.1532 / -5044.1531 | 10,930 / 10,951 | 193.9 s |

**libsvm と同じアルゴリズムにすると、非線形の SVM でも sklearn より
速くなります。** 同じ K の上の `SVC(kernel='precomputed')` に対して
1.1〜1.2 倍、カーネルの行をキャッシュ経由で必要なときに計算する
`SVC(kernel='rbf')` に対して約 2 倍です。反復回数も双対の目的関数も
一致し、テスト精度も両者で同じです(0.669 / 0.725 / 0.748)。代わりに
メモリを使います。n × n のカーネル行列全体(n = 10,000 で 800 MB)が
要り、`SVC(kernel='rbf')` はこれを持ちません。`svm-dual.scm` の列は、
翻訳ではなくアルゴリズムの差がどれだけ効くかを示しています。shrinking
がなく、alpha が 1 つ動くたびにメモの n 要素すべてを更新するので、
約 50〜90 倍遅くなります。

## L1 ロジスティック回帰と sklearn の比較

`examples/kernel-only/logistic-l1.scm` は、liblinear の L1 正則化
ロジスティック回帰ソルバ `solve_l1r_lr`(newGLMNET、Yuan, Ho, Lin 2011)を
そのまま書いたものです。Newton 反復ごとに損失の 2 次モデルを作り、L1 項と
合わせて座標降下(乱択順、shrinking)で最小化し、直線探索で歩幅を決めます。
勾配が 0 に留める座標は外側の作業集合から外します。
`LogisticRegression(l1_ratio=1, solver="liblinear", fit_intercept=False)`
が走らせるコードで、普通に翻訳しています。

測定は `bench/logistic-l1-compare.py`、1 コア、tol 1e-4、Newton 反復は
最大 100、3 回の最良値、sklearn 1.9.1、load average 約 2 です。こちらの
時間には X を列の形に転置する時間を含みます(liblinear も中で同じことを
します):

| n × p, C | `logistic-l1.scm` | `LogisticRegression`(liblinear) | 倍率 | 目的関数(ours / sklearn) | 非ゼロ数 | Newton 反復 |
|---|---|---|---|---|---|---|
| 1,000 × 50, 1 | 0.003 s | 0.005 s | 1.8 倍 | 229.43158 / 229.43158 | 43 / 43 | 13 / 13 |
| 5,000 × 200, 0.1 | 0.080 s | 0.117 s | 1.5 倍 | 64.465989 / 64.465993 | 74 / 74 | 18 / 16 |
| 20,000 × 500, 0.05 | 1.243 s | 2.361 s | 1.9 倍 | 108.71711 / 108.71713 | 144 / 144 | 19 / 17 |
| 100,000 × 200, 0.05 | 9.508 s | 18.153 s | 1.9 倍 | 324.5394 / 324.53954 | 124 / 124 | 19 / 19 |

SVM と同じ結果です。同じアルゴリズムなら約 2 倍速く、目的関数も非ゼロの
位置も同じになります。差は、ベクトル化される密なループと、liblinear の
`feature_node` のリストの差です。反復回数が 1〜2 回違うのは、乱択順の乱数が
別の系列だからです。損失が 2 次式ではないので、ここでは `--derive` が
見つける Gram 形はありません。`scm2cpp_learn.CovLogistic` は同じ問題を別の
アルゴリズム(固定した X'X/4 による majorization と lasso の降下)で解くもの
で、同じアルゴリズムどうしの比較はこの表です。

これらのソルバはパッケージにも入っています。`scm2cpp_learn.LinearSVM`、
`KernelSVM`、`L1LogisticRegression` は、`svm-liblinear.scm`、`svm-smo.scm`、
`logistic-l1.scm` を 1 つのライブラリに翻訳したもので、隣に epsilon-SVR の
`LinearSVR` と `KernelSVR` もあります(liblinear のものは `svr-liblinear.scm`、
libsvm のものは `svm-smo.scm` の同じ SMO。そのソルバは任意の 1 次の項を取り、
2n 変数を n 本のカーネル行に対応させます)。使い方は scikit-learn
と同じ(`fit`、`predict`、`decision_function`)です。パッケージから使って
測った表はパッケージの README にあります。

## NMF の導出と sklearn の比較

`examples/kernel-only/nmf-cd.scm` は、scikit-learn の `NMF(solver="cd")`
の反復を素朴な形で書いたものです。半ステップごとに残差 R = X − W H を
作り、一方の因子の座標を掃引して、R をもう一方の列の方向に動かします。
Gram 行列はどこにも出てきません。`--derive` は R を作業領域として見つけ、
外に出した H H' の上で R H' をメモにします。そのうえで R を作る処理をメモに
分配します(`R H' = X H' − W (H H')`。このカーネルのために足した規則)。
そのため R は作られません。結果は scikit-learn の
`_update_coordinate_descent` が手で作っている形 `XHt − W HHt` そのもので、
`--blas` / `--cublas` がその積を (cu)BLAS に渡します
(`derive: nmf-half: raise differencing matmul distribute guard`)。

測定は `bench/nmf-compare.py`。scikit-learn の
`NMF(solver="cd", init="custom")` を同じ W と H から、tol 1e-4、最大 200
反復、1 コア、load average 2 未満:

| n × p, k | sklearn | `nmf-cd.scm` 素朴 | `--derive --blas` | `--derive --cublas` | 反復(全部) | max \|W − W_sklearn\| |
|---|---|---|---|---|---|---|
| 1,000 × 500, 10 | 0.246 s | 4.57 s | 0.202 s(1.22 倍) | 0.645 s | 200 | 1.2e-12 |
| 5,000 × 2,000, 20 | 10.68 s | - | 8.09 s(1.32 倍) | 6.75 s(1.58 倍) | 200 | 2.5e-13 |
| 20,000 × 1,000, 30 | 29.04 s | - | 20.72 s(1.40 倍) | 16.38 s(1.77 倍) | 200 | 8.9e-13 |

導出によって、素朴なカーネルは scikit-learn の 20 倍遅い状態から、1.2〜
1.8 倍速い状態になります。反復の途中の値も 1e-12 まで同じです。パッケージ
には `scm2cpp_learn.CDNMF` として入っています(`DerivedLasso` と同じく
3 種類)。

## DBSCAN と sklearn の比較

`examples/kernel-only/dbscan.scm` は、総当たりの近傍による DBSCAN です。
内積は区画ごとの行列積(256 × 1024 の区画で、キャッシュに収まる)で計算
します。区画の上を 3 回走査します。近傍の数え上げ、core 点の union-find、
境界点を根が最小のクラスタに入れる処理です。近傍のリストは持たず、ラベル
は scikit-learn と完全に一致します(`dbscan_inner` と同じく、クラスタは
最小の core 点の順に番号が付きます)。`bench/dbscan-compare.py`、1 コア:

| n × p | sklearn `brute` | sklearn 既定 | `dbscan.scm --blas` | `--cublas` | ラベル一致 |
|---|---|---|---|---|---|
| 5,000 × 2 | 0.054 s | 0.017 s | 0.079 s | 0.343 s | 一致 |
| 20,000 × 2 | 0.622 s | 0.079 s | 1.067 s | 2.665 s | 一致 |
| 5,000 × 32 | 0.062 s | 0.061 s | 0.111 s | 0.217 s | 一致 |
| 20,000 × 32 | 0.964 s | 0.969 s | 1.757 s | 3.184 s | 一致 |

**これは速くなりません。** scikit-learn の総当たりは近傍のリストを持ち、
n² 個の距離を 1 回だけ計算します。このカーネルはリストを持たない代わりに
2 回計算します(数え上げとつなぎ合わせ)。1 回あたりは scikit-learn と
同じなので、全体では約半分の速さです。2 次元では scikit-learn の既定の木が
さらに 8 倍速くなります。cuBLAS 版はもっと遅くなります。GPU で走るのは積
だけで、しきい値の判定は CPU 側に残り、区画ごとに結果がバスを渡って
戻ってくるからです。効くのは距離としきい値判定を GPU 上で一体にした
カーネルですが、翻訳器が出すのは BLAS の呼び出しで、GPU のコードではあり
ません。そのため DBSCAN はパッケージに入れていません。

## GraphicalLasso、KMeans、RANSAC と sklearn の比較

scikit-learn のアルゴリズムをさらに 3 つ、サブセットでそのまま書いて普通に
翻訳しました(導出はしていません)。積が効くところは `matmul` で書いてある
ので、`--blas` が numpy と同じように BLAS に渡します。3 つとも scikit-learn
と同じ結果になります。反復回数や試行回数が同じで、ラベル・インライア・
精度行列・係数は 1e-14 まで一致します。測定はすべて 1 コアです。

**GraphicalLasso**(`examples/kernel-only/graphical-lasso.scm`):
`_graphical_lasso`(mode "cd")と内側の `enet_coordinate_descent_gram`
(gap-safe 規則込み)。`bench/glasso-compare.py` で、AR(1) 設計、n = 20p、
alpha 0.1、両側とも 100 反復です:

| p | sklearn | 素朴 | `--blas` |
|---|---|---|---|
| 50 | 0.302 s | 0.0167 s(18.1 倍) | 0.0066 s(45.5 倍) |
| 100 | 0.639 s | 0.148 s(4.3 倍) | 0.0436 s(14.7 倍) |
| 200 | 1.69 s | 1.36 s(1.2 倍) | 0.292 s(5.8 倍) |
| 400 | 7.74 s | 11.4 s(0.7 倍) | 3.32 s(2.3 倍) |
| 800 | 43.3 s | 92.9 s(0.5 倍) | 33.9 s(1.3 倍) |

p が小さいときの差は Python から来ています。scikit-learn は列ごとに Cython の
内側のソルバを 1 回呼び、そのほかの処理を numpy で行いますが、こちらはループ
全体が C++ です。p が大きいときの仕事は、列ごとの行列とベクトルの積 2 つです。
ループで書くと、これは足し算の順序を変えられない総和になるので、コンパイラは
ベクトル化できず、素朴な版は遅れます。`matmul` で書いて `--blas` を付けると、
scikit-learn と同じく dgemv になります。

**KMeans**(`examples/kernel-only/kmeans.scm`): `_kmeans_single_lloyd` と
同じ Lloyd 法で、距離 `|c|^2 − 2 x.c` は区画ごとの積で求めます。
`bench/kmeans-compare.py` で、両側とも同じ k 点から始めます:

| n × p, k | sklearn | `--blas` | `--cublas` |
|---|---|---|---|
| 10,000 × 20, 8 | 0.021 s | 0.010 s(2.1 倍) | 0.256 s |
| 100,000 × 20, 16 | 0.346 s | 0.394 s(0.88 倍) | 1.49 s |
| 100,000 × 100, 32 | 1.26 s | 1.21 s(1.04 倍) | 2.42 s |
| 200,000 × 50, 64 | 3.41 s | 3.33 s(1.02 倍) | 7.55 s |

**scikit-learn と互角です。** scikit-learn の Lloyd 法はもともと BLAS の上の
Cython なので、同じアルゴリズムでは差が残りません。cuBLAS 版は、小さな区画が
毎回バスを渡るので負けます。KMeans はパッケージに入れていません。

**RANSAC**(`examples/kernel-only/ransac.scm`): `LinearRegression` を使う
`RANSACRegressor.fit` で、scikit-learn が引くのと同じ部分集合を渡します
(パッケージも同じ引き方をします)。`bench/ransac-compare.py`、max_trials 1000:

| n × p, 外れ値 | sklearn | `ransac.scm` | 試行回数(両者) |
|---|---|---|---|
| 1,000 × 3, 20% | 0.0155 s | 0.0128 s(1.2 倍) | 9 |
| 10,000 × 5, 40% | 0.0944 s | 0.0321 s(2.9 倍) | 98 |
| 100,000 × 10, 30% | 0.270 s | 0.160 s(1.7 倍) | 97 |
| 20,000 × 20, 50% | 1.23 s | 0.508 s(2.4 倍) | 1,000 |

差はここでも、scikit-learn が試行ごとに払う Python と入力検査の手間です。
パッケージには `CDGraphicalLasso` と `LinearRANSAC` が入っています。

## SGD、OMP、LARS と sklearn の比較

最後の 3 つも、sklearn のコードをそのまま書いて普通に翻訳しました。

- `examples/kernel-only/sgd.scm`: `_plain_sgd`。SGDClassifier の hinge と
  学習率 "optimal"、SGDRegressor の二乗誤差と "invscaling" の 2 つの設定。
  重みはスケール係数とベクトルの積で持ちます。
- `omp.scm`: `orthogonal_mp_gram` / `_gram_omp`。
- `lars.scm`: Gram 行列を使う `_lars_path_solver` で、"lar" と "lasso"。
  lasso で変数が外れるときの、Givens 回転によるコレスキー因子の更新も
  含みます。

`bench/sgd-omp-lars-compare.py` で、同じデータの上で scikit-learn と比べ
ました(1 コア):

| 推定器, n × p | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| SGDClassifier, 10,000 × 20 | 0.018 s | 0.005 s | 3.3 倍 | エポック 30 / 30、重みが同一 |
| SGDClassifier, 100,000 × 50 | 0.159 s | 0.101 s | 1.6 倍 | 同一 |
| SGDClassifier, 50,000 × 500 | 2.24 s | 2.08 s | 1.1 倍 | 同一 |
| SGDRegressor, 100,000 × 50 | 0.114 s | 0.090 s | 1.3 倍 | 同一 |
| OrthogonalMatchingPursuit, 2,000 × 100 | 0.004 s | 0.001 s | 2.8 倍 | 同じ列、係数 3e-15 |
| OrthogonalMatchingPursuit, 20,000 × 1,000 | 0.381 s | 0.350 s | 1.1 倍 | 係数 3e-15 |
| Lars, 2,000 × 100 | 0.004 s | 0.001 s | 3.8 倍 | 20 / 20 ステップ、係数 1e-15 |
| Lars, 20,000 × 1,000 | 0.465 s | 0.352 s | 1.3 倍 | 200 / 200 ステップ、係数 5e-15 |
| LassoLars, 2,000 × 100 | 0.006 s | 0.001 s | 5.0 倍 | 38 / 38 ステップ、係数 2e-15 |
| LassoLars, 20,000 × 1,000 | 0.404 s | 0.333 s | 1.2 倍 | 104 / 104 ステップ、係数 4e-15 |

SGD は両側とも `shuffle=False` で走らせていて、重みはビット単位で同じに
なります。scikit-learn の shuffle は独自の xorshift 乱数を使っていて、
ビット演算のないサブセットでは同じ乱数を作れないためです。速さの差は
ここでも scikit-learn がステップごとに払う Python の分で、コンパイル済みの
仕事が大きくなるほど縮みます。lasso で変数が外れる経路でも、`LassoLars` は
ステップごとに一致します。

これらのカーネルを書く中で、翻訳器を 2 か所直しました。
- `(expt x y)` を `std::pow` として出すようにした。
- α 変換で付ける新しい名前が、それまでに束縛された名前だけでなく、
  プログラムに現れるすべての名前と重ならないようにした。

パッケージには、5 つとも `SGDLinearClassifier`、`SGDLinearRegressor`、
`GramOMP`、`GramLars`、`GramLassoLars` として入っています。

## L2 ロジスティック回帰と Huber 回帰(L-BFGS)と sklearn の比較

scikit-learn の既定の `LogisticRegression` と `HuberRegressor` は、どちらも
目的関数を scipy の L-BFGS-B に渡しています。どちらも全体をそのまま書きました。

- `examples/kernel-only/lbfgs.scm`: これらに対して動く L-BFGS-B。10 組の
  記憶からの方向、L-BFGS-B の定数での MINPACK-2 の More-Thuente 直線探索、
  停止判定と再始動を含みます。Huber のスケールのように下限のある変数が
  1 つあるときは、L-BFGS-B と同じく一般化コーシー点と部分空間ステップを
  取ります。
- `logistic-lbfgs.scm` / `huber.scm`: 目的関数と勾配(二項・多項損失の
  `LinearModelLoss`、`_huber_loss_and_gradient`)。積は `matmul` で書き、
  `--blas` で翻訳します。

`bench/lbfgs-compare.py` の結果です(1 コア、負荷 1.5 程度):

| 推定器, n × p(クラス数) | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| LogisticRegression, 500 × 20 (2) | 0.0021 s | 0.0003 s | 8.3 倍 | 反復 8 / 8、係数 2e-16 |
| LogisticRegression, 5,000 × 100 (2) | 0.0081 s | 0.0048 s | 1.7 倍 | 10 / 10、2e-16 |
| LogisticRegression, 5,000 × 100 (5) | 0.0262 s | 0.0152 s | 1.7 倍 | 15 / 15、4e-14 |
| LogisticRegression, 50,000 × 200 (2) | 0.223 s | 0.207 s | 1.1 倍 | 11 / 11、1e-15 |
| LogisticRegression, 50,000 × 200 (5) | 0.662 s | 0.569 s | 1.2 倍 | 17 / 17、1e-13 |
| HuberRegressor, 500 × 20 | 0.0043 s | 0.0002 s | 18 倍 | 15 / 15、2e-16 |
| HuberRegressor, 5,000 × 100 | 0.0305 s | 0.0098 s | 3.1 倍 | 16 / 16、2e-16 |
| HuberRegressor, 50,000 × 200 | 1.170 s | 0.464 s | 2.5 倍 | 16 / 16、1e-15 |
| HuberRegressor, 200,000 × 100 | 1.708 s | 0.653 s | 2.6 倍 | 12 / 12、1e-15 |

反復は 1 回ずつ一致し、係数も丸め誤差の範囲で一致します。直線探索が同じ
ステップを試すためです。大きな二値ロジスティック回帰は、両側とも 1 回の評価が
行列ベクトル積 2 回なので、倍率は 1 に近くなります。Huber で差が大きいのは、
scikit-learn が評価のたびにインライアとアウトライアを新しい配列に切り出して
いるためです。

これらのカーネルに合わせて、ランタイムと翻訳器を 2 か所変えました。
- `scm2cpp-blas.hpp` の `blas_gemm` は、実行時に m か n が 1 のとき
  (ロジスティック回帰の 1 クラス分など)dgemv を呼ぶ。OpenBLAS の dgemm は
  次元が 1 だと 3 割遅かった。
- `(exact->inexact n)` を `double(n)` として出す。`(* 1.0 n)` と違って
  `n` の型を変えない。

パッケージには 2 つとも `LBFGSLogisticRegression`、`LBFGSHuberRegressor`
として入れました。

## 混合ガウス、FastICA、PCA と sklearn の比較

scikit-learn の推定器をさらに 3 つ、全体をそのまま書いて `--blas` で翻訳しました。

- `examples/kernel-only/gmm.scm`: full 共分散の `GaussianMixture`。
  - M ステップでは、平均と共分散を行列積で求め、コレスキー因子と精度因子を作ります。
  - E ステップは X U - mu U から計算し、下界の変化で止めます。
- `fastica.scm`: 既定の設定の `FastICA`。
  - 白色化は X'X の固有ベクトルから作り、符号は scikit-learn が X の特異ベクトルに付けるのと同じにします。
  - そのあと parallel 反復と対称無相関化を行います。
- `pca.scm`: 共分散の固有ベクトルによる `PCA`。縦長の設計行列で scikit-learn の "auto" が選ぶ解法です。

後の 2 つは `sym-eigen.scm` を共有しています。Householder 変換による
三重対角化と陰的 QL 法を、サブセットで書いたものです。

`bench/gmm-ica-pca-compare.py` の結果です(1 コア、両側とも同じ初期値、random_state 0):

| 推定器, n × p | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| GaussianMixture, 2,000 × 5 (4 成分) | 0.0078 s | 0.0032 s | 2.4 倍 | 反復 3 / 3、4e-16 |
| GaussianMixture, 20,000 × 10 (8) | 0.125 s | 0.058 s | 2.1 倍 | 3 / 3、9e-16 |
| GaussianMixture, 20,000 × 10 (8、重なりあり) | 0.288 s | 0.137 s | 2.1 倍 | 9 / 9、5e-15 |
| GaussianMixture, 100,000 × 20 (5) | 1.011 s | 0.618 s | 1.6 倍 | 4 / 4、1e-14 |
| FastICA, 5,000 × 8 | 0.0116 s | 0.0085 s | 1.4 倍 | 27 / 27、6e-13 |
| FastICA, 50,000 × 10 | 0.083 s | 0.075 s | 1.1 倍 | 17 / 17、3e-13 |
| FastICA, 100,000 × 30 | 1.059 s | 0.741 s | 1.4 倍 | 21 / 21、3e-11 |
| PCA, 1,000 × 10 | 0.0005 s | 0.0001 s | 4.2 倍 | 6e-15 |
| PCA, 10,000 × 50 | 0.0021 s | 0.0015 s | 1.3 倍 | 4e-13 |
| PCA, 100,000 × 50 | 0.0214 s | 0.0150 s | 1.4 倍 | 4e-14 |
| PCA, 20,000 × 200 | 0.0270 s | 0.0331 s | 0.8 倍 | 2e-13 |
| PCA, 50,000 × 500 | 0.248 s | 0.406 s | 0.6 倍 | 3e-12 |

混合ガウスの時間には、両側とも KMeans による初期化が入っています
(パッケージは初期化に scikit-learn の KMeans をそのまま使います)。

PCA はサブセット側が負けるところです。特徴量が 100 を超えたあたりから
固有値問題が時間の大半を占め、LAPACK のブロック化された分割統治法 `dsyevd` が、
ブロック化していない QL 法に勝ちます。最初に書いた Jacobi 法の版は、
500 特徴量で 14 倍遅くなっていました。

FastICA の tanh は 1 - 2 / (e^2x + 1) で計算しています。C ライブラリの `tanh` は
ベクトル化されず、それを使うと全体が scikit-learn の 0.6 倍の速さに落ちたためです。

パッケージには 3 つとも `EMGaussianMixture`、`ParallelFastICA`、`CovPCA` として
入れました。

## Perceptron、passive-aggressive、ARD、LassoLarsIC、L1 の線形 SVM

さらに 5 つ、どれも scikit-learn のアルゴリズムそのものをサブセットで書いたものです。

- `sgd.scm`: scikit-learn の `_plain_sgd` のほかの設定も扱うようにしました。
  - 損失: perceptron の hinge(閾値 0)、epsilon-insensitive 損失
  - 学習率: "constant"、passive-aggressive の "pa1" / "pa2"
  - 正則化なし

  これで `Perceptron` と、scikit-learn 1.8 で `PassiveAggressiveClassifier` /
  `PassiveAggressiveRegressor` の置き換えになった設定が再現できます。
- `ard.scm`: n >= p の `ARDRegression`。各反復で、残っている特徴の
  diag(lambda) + alpha G に scipy の `pinvh` を取ります(固有分解は
  `sym-eigen.scm`)。
  - scikit-learn は残っている特徴の Gram を毎回 X から作り直します。
  - フラグを立てると、1 回だけ作った X'X から取り出します。ループ不変の積を
    手でループの外に出したもので、表には両方を載せました。
- `lars.scm`: 経路を `lars_path(return_path=True)` と同じ形で記録するように
  しました。`LassoLarsIC` は、その経路上の点を scikit-learn の情報量規準で
  選びます。パッケージでは残差平方和を各点で X から計算せず、Gram から
  求めます(|y - Xc|^2 = y'y - 2c'X'y + c'Gc)。
- `svm-l1.scm`: liblinear の `solve_l1r_l2_svc` で、
  `LinearSVC(penalty="l1", dual=False)` が走らせるコードです。座標の乱択順は
  liblinear と別の乱数で作るので、一致は丸め誤差ではなく収束許容誤差の範囲です。

`bench/linear-variants-compare.py` の結果です(1 コア、SGD は `shuffle=False`):

| 推定器, n × p | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| Perceptron, 10,000 × 20 | 0.0043 s | 0.0014 s | 3.0 倍 | エポック 8 / 8、同一 |
| Perceptron, 100,000 × 50 | 0.0785 s | 0.0516 s | 1.5 倍 | 同一 |
| SGDClassifier pa1, 10,000 × 20 | 0.0056 s | 0.0026 s | 2.2 倍 | 9 / 9、同一 |
| SGDRegressor epsilon-insensitive pa1, 100,000 × 50 | 0.112 s | 0.091 s | 1.2 倍 | 7 / 7、同一 |
| ARDRegression, 20,000 × 100 | 0.054 s | 0.034 s | 1.6 倍 | 3 / 3、1e-14 |
| ARDRegression、Gram を巻き上げ, 20,000 × 100 | 0.054 s | 0.018 s | 3.1 倍 | 3 / 3、1e-14 |
| ARDRegression、Gram を巻き上げ, 100,000 × 200 | 0.697 s | 0.235 s | 3.0 倍 | 3 / 3、8e-14 |
| LassoLarsIC (aic), 5,000 × 100 | 0.041 s | 0.0049 s | 8.3 倍 | 100 / 100 ステップ、9e-16 |
| LassoLarsIC (aic), 200,000 × 100 | 2.867 s | 0.141 s | 20 倍 | 100 / 100、6e-16 |
| LinearSVC l1, 5,000 × 100 | 0.779 s | 0.699 s | 1.1 倍 | 目的関数 4e-7 |
| LinearSVC l1, 100,000 × 50 | 4.837 s | 3.189 s | 1.5 倍 | 目的関数 8e-8 |

いちばん差が大きいのは LassoLarsIC です。scikit-learn は情報量規準を、
n × 経路の点数の行列積と SVD による最小二乗で計算しますが、同じ値は Gram に
すでに入っています。

これで、以前に挙げた候補はすべて実装しました。パッケージには `SGDPerceptron`、
`SGDLinearClassifier` / `SGDLinearRegressor` の新しい設定、`CovARDRegression`、
`GramLassoLarsIC`、`L1LinearSVM` として入れました。

## GLM、交差検証つきの推定器、Theil-Sen

- `examples/kernel-only/glm.scm` は `lbfgs.scm` の 3 つ目の目的関数です。
  `PoissonRegressor`、`GammaRegressor`、`TweedieRegressor`
  (log リンクの half deviance、power 0 は恒等リンク)を扱い、初期値は
  scikit-learn と同じです。
- 交差検証つきの推定器は、パッケージ側で既存のカーネルを組み合わせています。
  - `LogisticRegressionCV`: 分割ごとに C の経路を、前の C の解から温めて解く。
  - `LarsCV` / `LassoLarsCV`: 各分割の LARS 経路を、全分割の alpha の和集合に補間する。
  - `OrthogonalMatchingPursuitCV`: 経路を記録するようにした `omp.scm` を使う。

  分割は `KFold` / `StratifiedKFold`(shuffle なし)と同じ規則で作ります。
  LarsCV のテスト誤差は、テスト分割の Gram から計算します。
- `theilsen.scm` は `TheilSenRegressor` です。部分集合ごとに当てはめ(正方なら
  そのまま解き、特異なら gelss と同じ最小ノルム解)、そのあと修正 Weiszfeld 法で
  空間中央値を求めます。

`bench/glm-cv-compare.py` の結果です(1 コア):

| 推定器, n × p | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| PoissonRegressor (alpha 1e-3), 2,000 × 20 | 0.0022 s | 0.0004 s | 6.0 倍 | 反復 8 / 8、2e-16 |
| GammaRegressor (alpha 1e-3), 50,000 × 100 | 0.0719 s | 0.0647 s | 1.1 倍 | 7 / 7、1e-15 |
| TweedieRegressor (power 1.5), 50,000 × 100 | 0.0740 s | 0.0654 s | 1.1 倍 | 7 / 7、9e-16 |
| LogisticRegressionCV, 2,000 × 20 | 0.0816 s | 0.0124 s | 6.6 倍 | 同じ C、2e-16 |
| LogisticRegressionCV, 20,000 × 50 (3 クラス) | 0.617 s | 0.389 s | 1.6 倍 | 同じ C、1e-11 |
| LarsCV, 2,000 × 50 | 0.0348 s | 0.0053 s | 6.6 倍 | 同じ alpha、4e-16 |
| LassoLarsCV, 50,000 × 200 | 1.297 s | 0.593 s | 2.2 倍 | 同じ alpha、7e-16 |
| OrthogonalMatchingPursuitCV, 50,000 × 200 | 1.416 s | 0.517 s | 2.7 倍 | 同じ k、3e-16 |
| TheilSenRegressor, 1,000 × 5 | 0.309 s | 0.192 s | 1.6 倍 | 5 / 5、4e-15 |
| TheilSenRegressor, 5,000 × 10 | 0.885 s | 0.669 s | 1.3 倍 | 5 / 5、3e-15 |

大きな GLM は、両側とも 1 回の評価が行列ベクトル積 2 回なので、1.1 倍に
とどまります。

TheilSen の時間の大半は、両側とも `RandomState.choice` で 1 万個の部分集合を
引く部分です。部分集合を scikit-learn と同じにするため、この抽選はそのまま
残しています。当てはめと中央値の計算だけなら 8 ms で、scikit-learn は
約 200 ms かかっています。

パッケージには `LBFGSPoissonRegressor`、`LBFGSGammaRegressor`、
`LBFGSTweedieRegressor`、`LBFGSLogisticRegressionCV`、`GramLarsCV`、
`GramLassoLarsCV`、`GramOMPCV`、`WeiszfeldTheilSen` として入れました。

## F 統計量と RFE による特徴選択、デバイス上の Gram

- `examples/kernel-only/fscore.scm` は scikit-learn の `f_regression`
  (`r_regression` 経由)と `f_classif`(`f_oneway`)です。多数の目的変数を
  1 回の呼び出しで扱うので、X'Y は 1 回の行列積になり、`--cublas` では
  デバイスで計算します。scikit-learn は 1 回に 1 つの目的変数を扱います。
- `rfe.scm` は `Ridge` / `LinearRegression` を使う `RFE` です。
  - 中心化した Gram 行列と、そのコレスキー因子は 1 回だけ作ります。
  - 落とした特徴は、平面回転で因子から取り除きます(`lars.scm` の
    `cholesky_delete`)。
  - 各回、係数の 2 乗の安定な順で順位を付けます。
  - scikit-learn は毎回 X から当てはめ直しています。
- `gram.scm` は X'X と X'Y だけを作るカーネルです。パッケージは
  `fscore.scm`、`rfe.scm`、`pca.scm` と合わせて 1 つの `--cublas` ライブラリに
  まとめます。Gram 経路の推定器は、デバイスがあって行列積が大きいときにこれを
  使います。

`bench/select-compare.py` の結果です(1 コア + RTX 4090):

| 呼び出し, n × p | sklearn | ours | 倍率 | 一致 |
|---|---|---|---|---|
| f_regression, 100,000 × 500, 目的変数 1 | 0.152 s | 0.078 s | 1.9 倍 | F 3e-15 |
| f_regression, 20,000 × 1,000, 目的変数 100(デバイス) | 6.07 s | 0.125 s | 49 倍 | F 2e-14 |
| f_regression, 100,000 × 200, 目的変数 200(デバイス) | 12.7 s | 0.399 s | 32 倍 | F 8e-14 |
| SelectKBest(f_classif), 100,000 × 500 | 0.448 s | 0.100 s | 4.5 倍 | 同じ特徴 |
| RFE(Ridge), 5,000 × 100 | 0.245 s | 0.0031 s | 80 倍 | 同じ順位、係数 2e-15 |
| RFE(Ridge), 50,000 × 300 | 38.7 s | 0.157 s | 246 倍 | 同じ順位、1e-14 |
| RFE(LinearRegression), 20,000 × 500 | 167 s | 0.160 s | 1,047 倍 | 同じ順位、1e-14 |

| デバイス上の Gram, n × p | sklearn | ours, CPU | ours, デバイス |
|---|---|---|---|
| LassoLarsIC, 100,000 × 300 | 3.44 s | 0.289 s | 0.201 s |
| LassoLarsCV, 100,000 × 300 | 3.98 s | 1.97 s | 1.53 s |
| PCA, 200,000 × 300 | 0.427 s | 0.421 s | 0.245 s |

RFE が千倍近く速いのは、当てはめ直しをしないためです。X から p 回当てはめる
代わりに、Gram 行列 1 つとコレスキー因子 1 つで済ませています。

デバイスが効くのは、1 つの行列積が時間の大半を占める場合だけです。
- 効く: f_regression の多数の目的変数、大きな Gram(LassoLarsIC、PCA の共分散)。
- 効かない: 特徴量が 100 程度のときや、分割ごとの X のコピーが時間を占めるとき。
  CPU と時間が変わりません。
- ほぼ効かない: 積のあいだにループが走る推定器(混合ガウス、FastICA、L-BFGS 系)。
  デバイス上でも高々 15% です。要素ごとの処理はホストに残り、その処理が
  書き換えた行列が、積のたびにバスを往復するためです。

パッケージには `f_regression`、`f_classif`、`SelectKBest`、`SelectPercentile`、
`GramRFE` として入れ、デバイス上の Gram は `GramLassoLarsIC`、`GramLarsCV`、
`GramLassoLarsCV`、`GramLars`、`GramLassoLars`、`CovPCA` が使います。

## 翻訳器が出す GPU カーネル(`--cuda`)

`--cuda` は、ふつうのカーネルのループを CUDA カーネルにします。判定には、
翻訳器が OpenMP の指示文のためにすでに持っていた依存解析を使います。
ループが書く要素はそれぞれ 1 つの反復だけのもので、反復をまたいで持ち越す
スカラーは和だけ、という条件です。なのでソースに注記は要りません。

その条件を満たし、本体がスカラーと配列要素だけを計算するループは、
`__global__` 関数になります。1 反復を 1 スレッドで受け持ち、和は atomic add で
まとめます。反復回数が `SCM2CPP_CUDA_MIN` 未満のときは、ホストのループで
走ります。

速さの元は、配列をデバイスに置いたままにすることです。実行時ヘッダ
(`scm2cpp-cuda.hpp`)は、デバイスの文が一度でも触った配列ごとに、デバイス上の
写しと 2 つの状態(ホストが最新か、デバイスが最新か)を持ちます。

- カーネルや cuBLAS の積は、デバイスに足りないものだけを送る。
- ホストの文は、ホストに足りないものだけを戻し、そのあと書いたものを記録する。

翻訳器がこの呼び出しを文ごとに入れます。そのため、反復のホスト側が小さな
配列しか触らなければ(FastICA の k × k の無相関化、L-BFGS の方向の計算)、
大きな配列は一度も動きません。

パッケージには、FastICA、混合ガウス、L-BFGS 系をこの方法で翻訳したものを
入れました。デバイスがあり、問題が 100 万要素以上のときに使います。

`bench/cuda-compare.py` の結果です(1 コア対 RTX 4090、CPU 版と同じ Scheme):

| 推定器, n × p | sklearn | ours, CPU | ours, `--cuda` | sklearn 比 | 一致 |
|---|---|---|---|---|---|
| LogisticRegression, 200,000 × 100 | 0.494 s | 0.289 s | 0.034 s | 14.5 倍 | 反復 6 / 6 / 6、2e-15 |
| PoissonRegressor, 200,000 × 100 | 0.371 s | 0.335 s | 0.036 s | 10.4 倍 | 8 / 8 / 8、1e-15 |
| HuberRegressor, 200,000 × 100 | 2.020 s | 0.725 s | 0.093 s | 21.8 倍 | 14 / 14 / 14、2e-16 |
| LogisticRegressionCV, 200,000 × 100 | 5.50 s | 5.15 s | 1.86 s | 3.0 倍 | 同じ C、1e-10 |
| FastICA, 200,000 × 20 | 3.223 s | 2.544 s | 0.479 s | 6.7 倍 | 59 / 59 / 59、1e-6 |
| GaussianMixture (8), 200,000 × 20 | 1.723 s | 1.053 s | 0.562 s | 3.1 倍 | 2 / 2 / 2、4e-16 |

デバイスは和を足す順番が違うので、結果は CPU 版と末尾の桁で違います。
FastICA は反復が誤差を増幅するので、差が少し大きくなります。反復回数は
変わりません。

LogisticRegressionCV の伸びがいちばん小さいのは、50 回の当てはめのたびに
分割したデータを送り直しているためです。

## ループ不変の積の導出

書き換えない配列から集めた列の積をループの中で作ると、同じ表の要素を何度も
計算し直すことになります。ARD の反復は残す特徴の Gram を X から作り
(`gk = Xk'Xk`、`xk[i,c] = x[i, idx[c]]`)、各要素は `(X'X)[idx[r], idx[c]]` です。
集めた列は不変なデータに、積に比べて費用のない演算(添字の参照)をかけた
もの(準不変)なので、内積は X そのものに対して一度だけ取り、参照は結果の方に
かければ済みます。

`--derive` は差分化の前にこれを行います(`rewrite-invariant.scm`、ログに
`invariant`)。ループの中で代入も束縛もされず、プログラムの関数に裸で渡され
もしない配列をループ不変とします。ループ内の `(matmul (transpose A) B)` の
各被演算子は、そのような配列そのものか、同じ文の並びの前方にあるその配列の
集め直し(間の文が、集め直しの読むものを書かないこと)です。集める元の配列は
関数のどこかの `with-arrays` で `(n p)` と宣言されている必要があり、これで集める
添字が列であることが分かります。表 `X'Z` はループの前に確保し、最初に使うとき
に `matmul` として作るので、`--blas` では `dsyrk`・`dgemm`・`dgemv` の 1 回に
なります。積は `gk[r,c] = T[idx[r], idx[c]]` の参照に変わり、ループの他の所が
`xk` を読まなければ `xk` の詰め込みは消えます。異なる 2 つの元(`Xk'Zk`)、
右がベクトルの場合(`Xk'y`)、配列全体の積も同じ規則です
(`probe/derive-invariant.scm`)。

集め直しの階数は任意です。数え上げループの入れ子 `a[v1,..,vr] = x[u1,..,ur]` で、
x の各軸の添字は、ループ変数そのもの(全体の軸)か、ちょうど 1 つのループ変数の式
(集める軸)です。例えば `x[i1, e1(c1), e2(c2), i2]`。積は `matmul` の各形のほか、
任意の `contract` でも構いません。和を取る添字は全体の軸になければなりません。
集めた行の和は、添字の 1 つ 1 つではなく添字の集合全体で決まるので、表の参照では
得られないからです。表は自由な軸を全体の長さで持ちます(`probe/derive-invariant.scm`
は 3 階の配列の 2 軸を集める場合と、行 `x[ridx[c], j]` を集める場合を含み、
後者の表は X X')。

縮約で書けないものはメモ化します。X を変えないループの中で、ループを持つ純粋な
関数の呼び出し `f(op(X, p1), p2)` を `(memo-call M (f ..) KEY ..)` にします。
M はループの前に確保する鍵から値への表で、f は異なる鍵ごとに 1 回だけ走ります
(ログに `memo`)。鍵は変わるものです。スカラーの引数と、ループの中で不変なデータ
から詰めた配列の引数については、その詰め込みが依存する値です。k 回のループで
`idx[c]` と読む添字配列は `(memo-range idx k)` として鍵に入ります。詰めた配列が他で
読まれない局所変数なら、詰め込みはメモの外れ側へ移ります。C++ は鍵のバイト列から
値への `std::unordered_map` に対する `scm2cpp::memo_get`(`scm2cpp.hpp`)。
`memo-call` は手でも書けます(`probe/memo-call.scm`)。

`ard.scm` の HOIST 0 は scikit-learn と同じく毎反復 X から Gram を作る形です。
`--derive --blas` で、手で書いた HOIST 1 と同じものになります。`ard` を `-M` で、
1 コア、tol 1e-8、ロードアベレージ 1.4:

| n x p(反復) | HOIST 0、`--blas` | HOIST 0、`--derive --blas` | 手書きの HOIST 1、`--blas` |
|---|---|---|---|
| 5,000 x 100 (28) | 0.046 s | 0.023 s | 0.021 s |
| 20,000 x 200 (14) | 0.267 s | 0.122 s | 0.109 s |
| 20,000 x 400 (18) | 1.124 s | 0.650 s | 0.607 s |

係数は HOIST 0 と 1e-15 まで一致します。残る差は最初の反復で X'X を作る分
(HOIST 1 はループの前に作る)です。p x p の積 1 回と、反復ごとの n k^2 の積の
交換なので、k が p に近ければ 2 回目の反復から得になります。最初から k が p より
ずっと小さいループのための条件分岐は導出しません。

## 固有分解 1 回の RidgeCV

`GramRidgeCV` を scikit-learn の `RidgeCV`(`cv=None`、一般化交差検証による 1 個抜き)と
比べます。`bench/eigen-compare.py`(`taskset -c 0` で `--threads 1`、および
`--threads all`。MKL 版、ロードアベレージ 1.5、3 回の最良)。X は正規乱数に 1 を足したもの、
y はその 10 列と雑音です。双方とも同じ alpha を選び、係数は 2e-13 まで一致します。

| 場合 | scikit-learn `RidgeCV` | `GramRidgeCV` | 比、1 コア | 比、20 コア |
|---|---|---|---|---|
| 200,000 x 200、alpha 3 個 | 2.04 秒 | 0.80 秒 | 2.6 倍 | 3.6 倍 |
| 200,000 x 200、alpha 50 個 | 26.6 秒 | 0.96 秒 | 27.7 倍 | 29.0 倍 |
| 20,000 x 500、alpha 50 個 | 9.64 秒 | 0.33 秒 | 28.9 倍 | 29.2 倍 |
| 2,000 x 5,000、alpha 50 個 | 3.16 秒 | 1.47 秒 | 2.1 倍 | 4.5 倍 |

どちらも固有分解(または SVD)は 1 回で、差はその後の alpha 1 個あたりの費用です。
scikit-learn は alpha ごとに n x p の因子の上を numpy で 1 回なめます。`ridge-gcv.scm` は
全 alpha の diag H と当てはめ値を (Z o Z) W と Z (R o W) の 2 つの積で作るので、
alpha 50 個でも 3 個とほぼ同じ時間です。alpha 3 個での差は分解の違いで、X'X を dsyrk、
p x p を dsyevd とするのに対し、scikit-learn は n x p の設計行列の SVD です。横長の場合は
双方とも Xc Xc' の n x n の固有分解が時間の大半です。

## 部分空間反復の KernelPCA

`GramKernelPCA` を scikit-learn の `KernelPCA` と比べます。`bench/eigen-compare.py`
(MKL 版、ロードアベレージ 1.3、3 回の最良。X は正規乱数、gamma は 1/p)。双方とも
カーネル行列の作成と中心化は全体の 1 割にはるかに満たず、残りは固有値問題です。

| 場合 | scikit-learn `KernelPCA` | `GramKernelPCA` | 比、1 コア | 比、20 コア |
|---|---|---|---|---|
| rbf、3,000 x 20、5 成分 | 1.11 秒(ARPACK) | 0.35 秒(部分空間反復) | 3.2 倍 | 3.0 倍 |
| rbf、6,000 x 20、5 成分 | 4.63 秒(ARPACK) | 1.33 秒(部分空間反復) | 3.5 倍 | 4.2 倍 |
| rbf、3,000 x 20、50 成分 | 3.48 秒(密) | 3.63 秒(密) | 1.0 倍 | 1.2 倍 |
| linear、5,000 x 50、10 成分 | 19.8 秒(5,000 x 5,000 に ARPACK) | 0.002 秒(X'X) | 10,000 倍 | 2,100 倍 |

5 成分のとき scikit-learn の ARPACK は n x n の行列にベクトルを 1 本ずつ掛け、積のたびに
行列全体を読みます。部分空間反復は 30 列をまとめて掛ける(dgemm 1 回)ので、先頭の値が
ゆっくり下がるこのカーネル(5 番目が 1 番目の 0.92)でも 15 歩で残差 1e-12 に届きます。
効くのはブロックの大きさで、13 列では 235 歩かかりました。50 成分では双方が同じ番号の範囲で
dsyevr を呼び、100 列の部分空間反復はそれに負けた(1 コアで 6.2 秒対 3.6 秒)ので、
パッケージは scikit-learn が ARPACK を選ぶ範囲だけで使います。線形の行は n x n と p x p の
固有値問題の比較です。

## Gram 行列からの LDA

`GramLDA` を scikit-learn の `LinearDiscriminantAnalysis` と比べます。
`bench/eigen-compare.py`(MKL 版、ロードアベレージ 2.1〜2.8、3 回の最良。X は正規乱数で、
クラスごとに全特徴を 0.1 ずつずらす)。係数は 4e-13 まで、予測は完全に一致します。

| 場合 | scikit-learn | `GramLDA` | 比、1 コア | 比、20 コア |
|---|---|---|---|---|
| svd(既定)、200,000 x 100、5 クラス | 4.80 秒 | 0.092 秒 | 52 倍 | 35 倍 |
| svd、50,000 x 500、10 クラス | 4.07 秒 | 0.25 秒 | 16 倍 | 14 倍 |
| lsqr、200,000 x 100、5 クラス | 0.42 秒 | 0.089 秒 | 4.7 倍 | 8.9 倍 |
| eigen、200,000 x 100、5 クラス | 0.56 秒 | 0.094 秒 | 6.0 倍 | 12 倍 |

scikit-learn の既定のソルバは、n x p の設計行列をクラスごとに中心化した写しを作り、
尺度をそろえて SVD を取ります(200,000 x 100 に LAPACK の dgesdd)。`GramLDA` は設計行列を
1 回読んでクラス平均と X'X を作り、p x p の固有値問題を解きます。これで同じ右特異ベクトルと
特異値が得られます。lsqr と eigen では scikit-learn がクラスごとの共分散と全体の共分散を
設計行列から作る(積が 3 回)ところを、パッケージは Gram 1 回で済ませます。

## Gram 行列からの TruncatedSVD

`GramTruncatedSVD` を scikit-learn の `TruncatedSVD`(既定の randomized と、厳密な arpack)と
比べます。`bench/eigen-compare.py`(MKL 版、ロードアベレージ 1.8〜3.0、3 回の最良。X は正規乱数で、
列の尺度を 3 から 0.2 まで直線的に下げたもの)。パッケージの成分は arpack と 5e-13 まで一致し、
randomized は値がゆっくり下がるこのスペクトルでは両者と最大 1.3 ずれます。

| 場合 | scikit-learn | `GramTruncatedSVD` | 比、1 コア | 比、20 コア |
|---|---|---|---|---|
| 200,000 x 100、10 成分、randomized | 1.16 秒 | 0.22 秒 | 5.4 倍 | 7.0 倍 |
| 200,000 x 100、10 成分、arpack | 4.46 秒 | 0.22 秒 | 20 倍 | 25 倍 |
| 50,000 x 500、20 成分、randomized | 1.27 秒 | 0.39 秒 | 3.3 倍 | 5.1 倍 |
| 50,000 x 500、20 成分、arpack | 10.1 秒 | 0.41 秒 | 24 倍 | 21 倍 |
| 5,000 x 2,000、20 成分、randomized | 0.46 秒 | 0.96 秒 | 0.5 倍 | 3.5 倍 |
| 5,000 x 2,000、20 成分、arpack | 5.17 秒 | 1.01 秒 | 5.1 倍 | 9.1 倍 |

パッケージは X'X を 1 回(dsyrk)作り、上位の固有対を dsyevr に求めます。arpack は X と X' に
ベクトルを 1 本ずつ掛け、randomized はブロックとの積を数回と QR と小さな SVD を行います。
特徴が 2,000 で成分が 20 なら、randomized の積は厳密な経路の O(n p^2 + p^3) より安く、
1 コアではその方が速くなります。

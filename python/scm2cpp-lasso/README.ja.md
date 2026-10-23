# scm2cpp-lasso

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/niitsuma/scm2cpp/blob/master/notebooks/compare-sklearn.ipynb)

*[English version](README.md)*

Gram 行列に対する座標降下による lasso。GPU 経路は任意です。ソルバは
Scheme で書かれ、[scm2cpp](https://github.com/niitsuma/scm2cpp) が C++ へ
翻訳したものです。

```console
$ pip install scm2cpp-lasso
```

Linux x86_64、macOS arm64(macOS 14 以降)、Windows AMD64 では wheel が入ります。
コンパイル済みなので、ビルドは要りません(Linux と macOS は OpenBLAS を同梱、Windows は
ループ版)。それ以外の環境では pip が sdist から
ビルドし、必要なのは C++17 コンパイラだけです。wheel には GPU のコードが入って
いません(wheel はデバイスを知り得ないため)。GPU 版を使うには、`nvcc` がパスに
ある機械で sdist から入れてください:

```console
$ pip install --no-binary scm2cpp-lasso scm2cpp-lasso
```

そうすると、バッチ GPU ソルバ、cuBLAS 版、`--cuda` の推定器も併せてビルド
されます。`nvcc` が無ければパッケージは同じように入って同じように動き、それらだけが
欠けます。

100 本の候補列のうち信号を担うのは 3 本。どれなのかをソルバに尋ねると、
その 3 本だけを答えます:

```python
import numpy as np
from scm2cpp_lasso import CovLasso

rng = np.random.default_rng(0)
X = rng.standard_normal((500, 100))          # 500 行、候補 100 列
beta = np.zeros(100)
beta[[7, 23, 61]] = [2.0, -1.5, 0.8]         # 効くのはこの 3 本だけ
y = X @ beta + 0.1 * rng.standard_normal(500)

model = CovLasso(X, y)                       # Gram 行列は一度だけ作る
path = model.fit_path(model.lambda_grid())   # 100 個の lambda、暖かい開始

fit = path[60]
for j in np.flatnonzero(np.abs(fit) > 1e-6):
    print(f"  x{j:<3} {fit[j]:+.3f}")
```

```console
  x7   +1.965
  x23  -1.474
  x61  +0.770
```

残る 97 本は厳密にゼロです — 罰則はそのためにあります — 係数は植えた値が
罰則の分だけゼロ側に縮んだものです。

インタフェースの残りは次のとおりです:

```python
from scm2cpp_lasso import cuda_available

lambdas = model.lambda_grid(num=100)        # lambda_max から下へ
path = model.fit_path(lambdas)              # 暖かい開始、逐次
grid = model.fit_path_batch(lambdas)        # すべての lambda をゼロから
one = model.fit(lambdas[60])                # どうしても 1 個だけなら
print("GPU:", cuda_available())
```

`fit` は `fit_path` の 1 要素の特殊例です。Gram 行列はコンストラクタで
作ってあるので、暖かい開始のパス全体は罰則 1 個とほとんど同じ値段 —
だからパスのほうが主インタフェースです。

目的関数は scikit-learn のもの (`fit_intercept=False`) と同じです。

    (1 / 2 nobs) ||y - X b||^2 + lam ||b||_1

罰則は特徴量自身の尺度における相関と比較されるので、`lam` の有効な範囲は
データに依存します。`lambda_max()` はすべての係数をゼロに保つ最小の罰則で、
`lambda_grid()` はそこから下へ歩きます — scikit-learn と同じ構成です。
列の尺度が大きく異なる場合は先に標準化してください。このソルバは代わりに
やってはくれません。

## scikit-learn との互換性

0.14.0 から、`fit(X, y)`(または `fit(X)`)を持つ推定器はすべて scikit-learn の
`BaseEstimator` と対応する mixin を継承します。`clone`、`get_params` / `set_params`、
`GridSearchCV`、`Pipeline`、`cross_val_score` がそのまま使え、44 本すべてが
`sklearn.utils.estimator_checks.check_estimator` を通ります(`check-sklearn.py` で
走らせます。想定内の失敗は 2 件です。1 つは `DesignLasso` に `n_iter_` がないことで、
導出したカーネルが掃引数を数えないためです。もう 1 つは `LBFGSLogisticRegressionCV` の
`n_iter_` が、温かい出発点で既に収束している C について 0 になることで、scikit-learn 自身の
`LogisticRegressionCV` も同じデータで 0 を返します)。scikit-learn は任意の依存のままで、
なければ numpy だけの代替が `get_params`、`set_params`、`score` と同じ入力検査を
受け持ちます。

```python
from sklearn.model_selection import GridSearchCV
from scm2cpp_lasso import GramLasso

GridSearchCV(GramLasso(), {"alpha": [0.01, 0.1, 1.0]}, cv=5).fit(X, y)
```

`CovLasso`、`CovRidge`、`DerivedLasso`、`CovLogistic`、`CovGroupLasso`、
`CovMultiTaskLasso` は、パス全体を一度に解く「データをコンストラクタで受ける」形のままです。
それぞれに切片付きの `fit(X, y)` 形が並んでいます(0.15.0):

| データをコンストラクタで | `fit(X, y)` | scikit-learn |
|---|---|---|
| `CovLasso` | `GramLasso`、`GramElasticNet` | Lasso, ElasticNet |
| `CovRidge` | `GramRidge` | Ridge |
| `DerivedLasso` | `DesignLasso` | Lasso |
| `CovLogistic` | `GramLogisticRegression` | LogisticRegression(l1_ratio=1, solver="liblinear") |
| `CovGroupLasso` | `GramGroupLasso`(`groups=None` なら lasso) | (なし) |
| `CovMultiTaskLasso` | `GramMultiTaskLasso`、`GramMultiTaskElasticNet` | MultiTaskLasso, MultiTaskElasticNet |

切片付きの 400 x 30 で scikit-learn と比べると、`DesignLasso` と
`GramGroupLasso(groups=None)` は `Lasso` と 1.5e-10 まで、multitask の 2 本は
`MultiTaskLasso` / `MultiTaskElasticNet` と 5e-14 まで一致し、`GramLogisticRegression` は
liblinear と目的関数が 8 桁まで同じで、予測も同じです。

包んでいる元のクラス(切片なしで、変更なし)と比べると(罰則 1 つ、1 コア)、
`fit_intercept=False` なら入力検査で 1 呼び出し 15〜30 us(0.06 ms の fit で最大 +50%)、
20000 x 200 では有限性の総和で 8〜14% 遅くなります(`assume_finite` なら総和はなし)。
切片ありだと列の平均の分が加わります。Gram 行列を使うものは X を複製して中心化せず
X'X を平均で補正するので、20000 x 200 で 20〜30%、`DesignLasso` はカーネルが中心化した
X そのものを要るので約 55% です。`GramLogisticRegression` はアルゴリズムの違いで liblinear より
遅く、20000 x 200 で 2.5 倍、小さな問題ではそれ以上です。この問題を速く解くのは
`L1LogisticRegression` です。

代償は入力の検査です。X は有限の 2 次元 float64 配列で、列数が fit のときと同じで
なければなりません。素の C 順 float64 の ndarray は直接検査し(有限かどうかは総和 1 回)、
それ以外(リスト、DataFrame、別の dtype)は scikit-learn の `validate_data` に回すので、
エラーは scikit-learn と同じものが出ます。検査だけの時間、1 呼び出しあたり
(`bench/sklearn-compat-overhead.py --checks`):

| X | fit | predict | predict(50 行) | validate_data |
|---|---|---|---|---|
| 200 x 10 | 13 us | 7 us | 9 us | 173 us |
| 2000 x 50 | 47 us | 36 us | 9 us | 224 us |
| 20000 x 200 | 2.7 ms | 3.2 ms | 13 us | 3.2 ms |

大きさで増えるのは有限性の総和で、`sklearn.set_config(assume_finite=True)` の下では
どの行も 3 us 前後です。呼び出し全体の変更前後(`bench/sklearn-compat-overhead.py`、
30 推定器、3 つの大きさ、負荷のある機械の 1 コアで新旧を交互に): 1 ms 以上の fit は
回ごとのばらつき(10% 程度)の内で変わらず、0.1 ms 前後の fit は 10〜30%(10〜40 us)
遅く、20000 x 200 の predict は約 2 倍(3 ms から 6 ms。有限性の総和が積そのものと
同じだけかかる)、小さな入力の predict は 5〜10 us 遅くなります。

## 推定器の一覧

各推定器について、再現している scikit-learn の推定器、翻訳元の Scheme カーネル
(`examples/kernel-only/` の下)、動く版、Intel の sklearnex が scikit-learn 側を
速くするかどうかを載せます。版: *loops* は素の翻訳、*BLAS* / *cuBLAS* は積を
(cu)BLAS に渡したもの、*--cuda* は翻訳器が出す GPU カーネル(`gpu_cuda/`)、
*GPU batch* は手書きの CUDA バッチソルバです。パッケージは入っている中で最速の版を
選びます。

| クラス | scikit-learn | Scheme カーネル | 版 | sklearnex による高速化 |
|---|---|---|---|---|
| `GramLasso` | Lasso(precompute=True)、切片付きの fit(X, y) | `lasso-cov.scm` | CPU | なし |
| `GramElasticNet` | ElasticNet(precompute=True)、切片付きの fit(X, y) | `lasso-cov.scm` | CPU | なし |
| `GramRidge` | Ridge、切片付きの fit(X, y)、目的変数は 1 本でも複数でも | numpy(Cholesky) | CPU | Ridge |
| `GramMultiTaskLasso` | MultiTaskLasso、切片付きの fit(X, Y) | `lasso-cov.scm` | CPU | なし |
| `GramMultiTaskElasticNet` | MultiTaskElasticNet、切片付きの fit(X, Y) | `lasso-cov.scm` | CPU | なし |
| `GramGroupLasso` | (なし。skglm の GroupLasso)、切片付きの fit(X, y) | `lasso-cov.scm` | CPU | - |
| `GramLogisticRegression` | LogisticRegression(l1_ratio=1, solver='liblinear')、優関数法 | `lasso-cov.scm` | CPU | なし |
| `DesignLasso` | Lasso、切片付きの fit(X, y)、設計行列から | `lasso-design.scm (--derive)` | loops / BLAS / cuBLAS | なし |
| `CovLasso` | Lasso, ElasticNet, lasso_path(precompute=True) | `lasso-cov.scm` | CPU; GPU batch (fit_path_batch, bootstrap) | なし |
| `CovLassoCV` | LassoCV, ElasticNetCV | `lasso-cov.scm` | CPU; GPU batch | なし |
| `DerivedLasso` | lasso_path、設計行列から | `lasso-design.scm (--derive)` | loops / BLAS / cuBLAS | なし |
| `CovMultiTaskLasso` | MultiTaskLasso, MultiTaskElasticNet | `lasso-cov.scm` | CPU | なし |
| `CovMultiTaskLassoCV` | MultiTaskLassoCV, MultiTaskElasticNetCV | `lasso-cov.scm` | CPU; GPU batch | なし |
| `CovGroupLasso` | (なし。skglm の GroupLasso) | `lasso-cov.scm` | CPU | - |
| `CovLogistic` | LogisticRegression(penalty='l1')、優関数法 | `lasso-cov.scm` | CPU | なし |
| `CovRidge` | Ridge(fit_intercept=False)、alpha のパス全体 | `lasso-cov.scm` | CPU | Ridge |
| `CovBayesianRidge` | BayesianRidge | `lasso-cov.scm` | CPU | なし |
| `CovARDRegression` | ARDRegression (n >= p) | `ard.scm` | loops / BLAS | なし |
| `GramLars` | Lars | `lars.scm` | CPU | なし |
| `GramLassoLars` | LassoLars | `lars.scm` | CPU | なし |
| `GramLassoLarsIC` | LassoLarsIC | `lars.scm` | CPU; デバイスの Gram | なし |
| `GramLarsCV` | LarsCV | `lars.scm` | CPU | なし |
| `GramLassoLarsCV` | LassoLarsCV | `lars.scm` | CPU; デバイスの Gram | なし |
| `GramOMP` | OrthogonalMatchingPursuit | `omp.scm` | loops / BLAS | なし |
| `GramOMPCV` | OrthogonalMatchingPursuitCV | `omp.scm` | loops / BLAS | なし |
| `LBFGSLogisticRegression` | LogisticRegression(solver='lbfgs') | `logistic-lbfgs.scm, lbfgs.scm` | loops / BLAS / --cuda | LogisticRegression |
| `LBFGSLogisticRegressionCV` | LogisticRegressionCV | `logistic-lbfgs.scm, lbfgs.scm` | loops / BLAS / --cuda | なし |
| `LBFGSHuberRegressor` | HuberRegressor | `huber.scm, lbfgs.scm` | loops / BLAS / --cuda | なし |
| `LBFGSPoissonRegressor` | PoissonRegressor | `glm.scm, lbfgs.scm` | loops / BLAS / --cuda | なし |
| `LBFGSGammaRegressor` | GammaRegressor | `glm.scm, lbfgs.scm` | loops / BLAS / --cuda | なし |
| `LBFGSTweedieRegressor` | TweedieRegressor | `glm.scm, lbfgs.scm` | loops / BLAS / --cuda | なし |
| `LinearSVM` | LinearSVC(loss='hinge') | `svm-liblinear.scm` | CPU | なし |
| `L1LinearSVM` | LinearSVC(penalty='l1', dual=False) | `svm-l1.scm` | CPU | なし |
| `KernelSVM` | SVC | `svm-smo.scm` | CPU | SVC |
| `LinearSVR` | LinearSVR | `svr-liblinear.scm` | CPU | なし |
| `KernelSVR` | SVR | `svm-smo.scm` | CPU | SVR |
| `L1LogisticRegression` | LogisticRegression(penalty='l1', solver='liblinear') | `logistic-l1.scm` | CPU | なし |
| `SGDLinearClassifier` | SGDClassifier(shuffle=False) | `sgd.scm` | CPU | なし |
| `SGDLinearRegressor` | SGDRegressor(shuffle=False) | `sgd.scm` | CPU | なし |
| `SGDPerceptron` | Perceptron(shuffle=False) | `sgd.scm` | CPU | なし |
| `LinearRANSAC` | RANSACRegressor (部分集合を与える) | `ransac.scm` | CPU | なし |
| `WeiszfeldTheilSen` | TheilSenRegressor | `theilsen.scm` | CPU | なし |
| `CDNMF` | NMF(solver='cd') | `nmf-cd.scm (--derive)` | loops / BLAS / cuBLAS | なし |
| `CDGraphicalLasso` | GraphicalLasso | `graphical-lasso.scm` | loops / BLAS | なし |
| `EMGaussianMixture` | GaussianMixture(covariance_type='full') | `gmm.scm` | loops / BLAS / --cuda | なし |
| `ParallelFastICA` | FastICA | `fastica.scm` | loops / BLAS / --cuda | なし |
| `CovPCA` | PCA(svd_solver='covariance_eigh') | `pca.scm` | loops / BLAS / cuBLAS | PCA |
| `f_regression, f_classif` | f_regression, f_classif | `fscore.scm` | loops / BLAS / cuBLAS | なし |
| `SelectKBest, SelectPercentile` | SelectKBest, SelectPercentile | `fscore.scm` | loops / BLAS / cuBLAS | なし |
| `GramRFE` | RFE(Ridge), RFE(LinearRegression) | `rfe.scm` | loops / BLAS / cuBLAS | 中の Ridge |

## 2 つのカーネル: `CovLasso` と `DerivedLasso`

ここまでの全部と、下の交差検証・ブートストラップ・GPU のメソッドは、
1 つのカーネルの上で走ります。numpy が Gram 行列を作り、その上を手書きの
座標降下の掃引(リポジトリの `examples/kernel-only/lasso-cov.scm` を C++
に翻訳したもの)が回る。使うならこちらです。

`DerivedLasso` はもう 1 つのカーネルで、よい推定器であるためではなく、
翻訳器の仕事を見せるためにあります。元は
`examples/kernel-only/lasso-design.scm`、残差形の座標降下 — scikit-learn の
`Lasso(precompute=False)` の中身のアルゴリズム — を numpy が持つままの X
(n 行 p 列、`x[i*p+j]`)の上の平坦なループで書き、残差は y から、列ノルムは
X から中で作るもので、Gram 行列はどこにも出てきません。翻訳器の
`--derive` がそれを Gram 形に変えます。ループを配列代数に持ち上げ、残差が
列のスカラー倍でしか更新されず列との内積でしか読まれないことを見て、
残差をメモ `c = X'r` に置き換え、それを保守する Gram 行列を罰則パスの
前に持ち上げ、列ノルムをその Gram の対角に畳み、3 つの積を `dsyrk` 1 回と
`dgemv` 2 回に畳み(`--blas`)、
全体を `(if (< p n) ..)` の下に置いて else 側に書かれたままの掃引を残す
— scikit-learn の `precompute='auto'` の規則を、書くのでなく導出したもの
です。その導出の C++ を、翻訳器が出したまま `DerivedLasso` が呼びます。
numpy は何も準備しません — X と y はそのまま渡り、転置コピーもノルム計算も
ありません。

```python
from scm2cpp_lasso import DerivedLasso, derived_backend

model = DerivedLasso(X, y)                   # X と y。Gram はカーネルが自分で作る
path = model.fit_path(model.lambda_grid())   # 1 回の呼び出しで暖かいパス全体
print(derived_backend())                     # 'cublas' / 'blas' / 'loops': この機械で入ったもの
gpu = DerivedLasso(X, y, backend="cublas")   # 指定もできる
```

lambda ごとの fit は、どの係数も `tol`(絶対値、既定 1e-8)より大きく
動かなかった掃引で終わり、`max_sweeps` が上限です。`tol=0.0` なら正確な
不動点まで回ります。1 つの導出の翻訳が 3 通りコミットしてあり、`pip` は
機械が許すものを作ります: CUDA ツールキットがあれば `--derive --cublas`
(3 つの積をデバイスで cuBLAS に。X は `fit_path` の呼び出しごとに 1 度
アップロード。デバイスが応えるときの既定)、`cblas.h` と OpenBLAS があれば
`--derive --blas`、どちらもなければ `--derive` だけ — 同じプログラムで Gram
行列がスカラーのループ入れ子のもの。正しいが大きな設計では遅い。パッケージディレクトリの `check-derived.py` が 2 つのカーネルと
scikit-learn に同じパスを解かせ、差と時間を出します。AR(1) 設計(ρ 0.9)、
lambda_max から 0.01 lambda_max までの罰則 20 本、1 コア、3 回の最良値
(負荷 3 前後)、Gram 行列をどこで作るにせよそれ込みの呼び出し全体:

| n × p                                   | 1,800 × 200 | 5,000 × 1000 | 100,000 × 200 | 100,000 × 500 |
|-----------------------------------------|-------------|--------------|---------------|---------------|
| `DerivedLasso`、cuBLAS(アップロード込み)         | 0.003 秒     | 0.024 秒      | 0.052 秒       | 0.11 秒        |
| `DerivedLasso`、CBLAS                    | 0.003 秒     | 0.076 秒      | 0.12 秒        | 0.44 秒        |
| `CovLasso(X, y).fit_path`、tol 1e-8      | 0.004 秒     | 0.080 秒      | 0.11 秒        | 0.42 秒        |
| sklearn `lasso_path(precompute=True)`、tol 1e-4 | 0.005 秒     | 0.10 秒       | 0.24 秒        | 0.76 秒        |

CBLAS の走りは `CovLasso` の numpy の Gram とパスと同じ `dsyrk`、同じ掃引で、
時間も同じです。cuBLAS の走りは同じプログラムの 3 つの積をデバイスでやる
もので、X のアップロード込みで、大きい 3 形状で scikit-learn の 4.2 倍・
4.5 倍・6.7 倍 — リポジトリの等作業表の数字に、カーネルの前に何も置かずに
パッケージから届いています: コンストラクタは X と y を持つだけで、残差と
列ノルムはカーネルが自分で取ります(ノルムは導出が Gram の対角に畳む)。
スレッドを増やしても構図はあまり変わりません。scikit-learn の掃引は
シングルスレッドの Cython で、スケールするのは Gram の積だけなので、BLAS
20 スレッドで `lasso_path` は大きい 3 形状で 0.051 / 0.227 / 0.450 秒、
対して cuBLAS 版は 0.023 / 0.050 / 0.113 秒(2.2 倍・4.5 倍・4.0 倍)、
CBLAS 版は `dsyrk` がスレッドでスケールして 0.025 / 0.036 / 0.123 秒
(2.0 倍・6.3 倍・3.7 倍)。GPU の数字は動きません。
tol=1e-12 まで回した参照との差は `DerivedLasso` がどのバックエンドでも
5e-8 以内(許容誤差は 1 掃引の最大移動の絶対値)、`CovLasso` は 2e-10 以内
(20 掃引ごとに検査して行き過ぎる)、scikit-learn は既定の許容誤差で 1e-3
以内です。

### 自分で導出するには

`DerivedLasso` が走らせているものは、翻訳器で Scheme から全部再現できます。
パッケージの `regenerate.sh` がやっていることを、カーネル 1 本分だけ手順に
したのが次です(Racket 8 と C++17 コンパイラ。`--blas` には CBLAS、
`--cublas` には CUDA ツールキット):

```console
$ git clone https://github.com/niitsuma/scm2cpp && cd scm2cpp
$ raco link --user vendor/rkanren                 # 機械ごとに 1 度
$ mkdir /tmp/k && cp examples/kernel-only/lasso-design.scm examples/kernel-only/soft-threshold.scm /tmp/k/
$ racket scm2cpp-file.scm -t scm2c.typ --derive --cublas -M -S /tmp/k/lasso-design.scm
derive: lasso-design: raise differencing merge matmul guard
```

標準エラーの `derive:` が発火したものを並べます: ループの配列代数への
持ち上げ、残差のメモへの差分化、列ノルムの Gram 対角への merge、積の縮約
への畳み込み、`(if (< p n) ..)` の guard。実行後、ソースの隣に
`lasso-design.hpp`(導出後のカーネルの C++: `blas_syrk` 1 回、`blas_gemv`
2 回、掃引)、`lasso-design_capi.cpp` と `lasso_design.py`(`-M` の C ABI と
ctypes ローダ — パッケージの `_loader_derived_*.py` はこれ)、
`lasso-design.expanded.scm`(`-S`: C++ になる前の導出後のプログラムを
Scheme で。導出が何をしたかはこれを読む)ができます。`--cublas` の代わりに
`--blas` なら CBLAS 版、どちらもなければループ版。パッケージなしで numpy
から呼ぶには:

```console
$ g++ -O2 -std=c++17 -shared -fPIC -I. -I$CUDA_HOME/include -o /tmp/k/liblasso-design.so \
      /tmp/k/lasso-design_capi.cpp -L$CUDA_HOME/lib64 -lcublas -lcudart   # --blas なら -lopenblas
$ cd /tmp/k && python3 -c 'import lasso_design'   # lasso_design.lasso_design(x, y, resid, xnorm, beta, lams, betas, iters, tol, n, p, nlam)
```

(`-M` は Python モジュール名をファイル名の `-` を `_` に読み替えて作り、
ローダは隣の `liblasso-design.so` を探します。)
`examples/kernel-only/README.md` は行優先のカーネルで同じ `-M` の流れを、
`python/PACKAGING.md` はそれを pip パッケージにする手順を説明しています。

## pip で入る他の lasso との比較

リポジトリの `bench/lasso-compare.py` は、同じ交差検証形の格子 —
4096 個の lambda を全てゼロから、p=200、n=1800 — を `pip install` で
入る全 lasso に解かせます: scikit-learn 1.9.1、celer 0.7.4、skglm 0.5、
RAPIDS cuML 26.8。各ソルバは自身の既定許容誤差(当方は厳しい 1e-8)、
計測外の warm-up 1 回つき、cuML はデータをデバイスに置いてから計測。
最終列は最小 lambda における目的関数の当方との差です:

| ソルバ | 時間 | 目的関数の差 |
|---|---|---|
| scm2cpp-lasso、CPU 1 コア (tol 1e-8) | 0.91 秒 | 0 |
| scm2cpp-lasso、GPU、lambda 1 つにブロック 1 つ | 0.044 秒 | 0 |
| sklearn `Lasso.fit` を lambda ごと | 9.6 秒 | +1.6e-09 |
| celer | 13.5 秒 | 0 |
| skglm | 14.5 秒 | +2.8e-17 |
| cuML(GPU) | 53.6 秒 | +9.1e-07 |

(他に何も走っていない機械で一度に取った 3 回実行の最良値; CUDA 12.9
上の cuML 26.08。)

celer と skglm は巨大で疎な設計行列のための道具で、この規模では
フィットごとの準備の費用がかさむだけです。cuML は 1 フィットの内側を並列化
するので 1 フィットが大きいときに勝ち、この規模では起動代が支配します。
当方の GPU は lambda を跨いで並列化します — 交差検証格子が実際に
差し出す並列軸はこちらです。

`CovLassoCV` はこの機構の上の scikit-learn `LassoCV` です — 同じ格子
構成、同じ連続 fold、同じ平均 MSE 最小の選択。構造的な節約が 2 つ
あります。fold の訓練 Gram は**引き算**(Gram は行について加法的なので
G − Xf'Xf は fold 1 個分の費用)であり、Gram ができた後は**下流が
n 行に二度と触れない** — 差が n とともに開くのはこのためです。GPU が
あれば格子全体が 1 回の起動です: (fold, alpha) のセルごとにスレッド
**ブロック** 1 つ、fold の Gram はその場で読む(デバイス上の Gram は
cv 個で cv × 100 個ではない)、ブロックのスレッド 0 が座標ステップを
行い、ブロック全体が相関の O(p) 更新を分担します。cv × 100 = 500 セル
は 1 スレッドずつではデバイスを埋めるに足りない問題数で、問題ごとの
ブロックがその数を十分な並列仕事に変えます。`bench/cv-grid-designs.py`
が代替案(セルごとに 1 スレッド、複数 alpha の warm 連続をスレッド
またはブロックごとに)を並べて計時し、試したどのサイズでもセルごと
ブロックが勝ちます。デバイスが応えれば GPU が既定(`force_cpu` で
warm CPU パス)。cv=5、alpha 100 個、CPU 1 コア、sklearn 1.9.1、
3 回実行の最良値、Gram 込みの推定器全体:

| n | p | CPU | CUDA | sklearn `LassoCV` |
|---|---|---|---|---|
| 1,800 | 200 | 0.21 秒 | 0.02 秒 | 0.10 秒 |
| 5,000 | 1000 | 1.48 秒 | 0.25 秒 | 0.90 秒 |
| 100,000 | 200 | 0.49 秒 | 0.34 秒 | 1.72 秒 |
| 100,000 | 500 | 1.32 秒 | 1.09 秒 | 4.82 秒 |

(他に何も走っていない機械 — 20 スレッドで負荷 2〜3 — で取った値。
sklearn の `LassoCV` は既定の `precompute='auto'` でここの全サイズ
(n > p)で Gram 経路を取り、fold の Gram をその fold の行から作り直す —
当方は全体から引く。)格子の起動そのものは n=1,800 で 9 ms、n=5,000,
p=1000 で 64 ms。n=100,000 の CUDA 列はほぼ全部が Gram の積で、CPU
パスも同じ積を払います。機構が効くのはいずれにせよ大きい n です:
Gram の下流は 100,000 行に二度と触れません。n=5,000, p=1000 では
sklearn の生 X 上の降下が当方の Gram 経由 CPU パスより速く、GPU が
その差を 3.5 倍返しにします。CPU と CUDA の選ぶ alpha は全サイズで
同一(係数 1e-14 一致)。sklearn とは n=5,000 で完全一致、それ以外は
ほぼ同点のところで 1 格子点のずれ(平均 MSE の相対差は高々 2.6e-4)で、sklearn の
tol=1e-10 なら全サイズで当方の alpha を選びます。

elastic net の交差検証も同じです。`CovLassoCV(l1_ratio=0.5)` と
`ElasticNetCV(l1_ratio=0.5)` を、同じ fold と同じ alpha 格子で比べました
(`bench/lasso-compare.py --cv-only --l1-ratio 0.5`、条件は上と同じ、
負荷 1 未満):

| n | p | CPU | CUDA | sklearn `ElasticNetCV` |
|---|---|---|---|---|
| 1,800 | 200 | 0.35 秒 | 0.02 秒 | 0.11 秒 |
| 5,000 | 1000 | 1.55 秒 | 0.26 秒 | 0.98 秒 |
| 100,000 | 200 | 0.52 秒 | 0.35 秒 | 1.76 秒 |
| 100,000 | 500 | 1.38 秒 | 1.15 秒 | 4.97 秒 |

傾向は lasso と同じです。CPU では 10 万行で 3.4〜3.6 倍、小さい 2 形では
sklearn より遅く、CUDA ではどの形でも 3.8〜5.5 倍。選ばれる alpha は 4 形とも
sklearn と同じで、係数の差は 8e-6 以内(sklearn の既定の許容誤差の範囲)です。

`CovMultiTaskLasso` と `CovMultiTaskLassoCV` は同じ機構上の multitask
族です — scikit-learn の `MultiTaskLasso`、`MultiTaskElasticNet`
(`l1_ratio` 経由)、`MultiTaskLassoCV`、`MultiTaskElasticNetCV` に
対応。罰則が W の各特徴行をタスク横断で束ねるため、座標更新は行の
L2 ノルムに対するブロック軟しきい値になります。C = X'Y − GW は
単一タスクの C と全く同様にタスクごとに維持され、Gram の下流は n 行に
触れません — カーネルは同じ翻訳済み Scheme(`mt-descend`)です。
fold は独立で、降下(ctypes)も積(BLAS)も GIL を放すので、`n_jobs`
スレッドが CV を fold 横断でスケールさせます。既定は sklearn の
`n_jobs=None` と同じ逐次で、ベンチは双方 BLAS 1 スレッド固定。GPU が
あれば CV 格子は `CovLassoCV` と全く同様に 1 回の起動 — (fold, alpha)
セルごとにブロック 1 つ、p × T の係数ブロックは共有メモリ
(`force_cpu` で降りられます)。プロトコルは上と同じ、タスク数 8、
単発 fit は alpha = 0.1 lambda_max、CV は両者同一の 100 alpha 格子:

| 推定器 | n | p | 当方 | 当方 `n_jobs=5` | 当方 CUDA | sklearn |
|---|---|---|---|---|---|---|
| MultiTaskLasso | 100,000 | 200 | 0.14 秒 | -- | -- | 0.76 秒 |
| MultiTaskLasso | 100,000 | 500 | 0.53 秒 | -- | -- | 1.7 秒 |
| MultiTaskLassoCV | 1,800 | 200 | 1.4 秒 | 0.51 秒 | 0.07 秒 | 0.42 秒 |
| MultiTaskLassoCV | 100,000 | 200 | 1.6 秒 | 0.64 秒 | 1.3 秒 | 74 秒 |
| MultiTaskElasticNetCV | 1,800 | 200 | 1.4 秒 | 0.49 秒 | 0.08 秒 | 0.75 秒 |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 秒 | 0.68 秒 | 1.3 秒 | 162 秒 |

(`MultiTaskElasticNet` の単発 fit は `MultiTaskLasso` と同時間。全列を
上の `CovLassoCV` 表と同じ空いた機械で一度に取った値、sklearn 1.9.1。
scikit-learn の multitask 推定器には Gram 経路がなく — path のコードが
2 次元の目的変数では `precompute=False` に落とす、"No Gram variant of
multi-task exists right now" — sklearn 列は全 n で生 X 上の降下です。
`LassoCV` では伸びなかった n で伸びるのはそのため。)
n=1,800 の逐次 CV は sklearn より遅い — 既定 tol=1e-8
は sklearn の 1e-4 の双対ギャップ停止より多く掃引し、そのサイズでは
節約できる行がない — そして GPU 格子は全体を 0.1 秒で済ませます。
n=100,000 では Gram 経路が 46 倍・100 倍先行し、絶対時間は n=1,800
からほぼ変わりません。そこでの CUDA 列は Gram の積で、CPU パスが作る
のと同じものです。係数は厳しい tol で sklearn と 1e-15
一致、CV 対も同じ alpha を選び係数は 1e-13 一致です。

## どちらのメソッドか

`fit_path` は 1 本のパスを歩き、各 lambda は前の解から始まります。降下は
正確に再開できるので、最初の 1 つを過ぎれば lambda あたりの費用はほとんど
ありません。`fit_path_batch` はすべての lambda をゼロから解きます。分割が
異なり、lambda をまたぐ暖かい開始が使えない交差検証の格子が必要とするのは
こちらです。問題どうしが独立なので、まとめて GPU に渡せます。

p=200、1800 行、400 個の lambda のパスで、RTX 4090 と i9-10900X の場合:

| 呼び出し | 時間 |
|---|---|
| `fit_path` (暖かい、逐次) | 0.091 秒 |
| `fit_path_batch` (GPU) | 0.047 秒 |
| `fit_path_batch(force_cpu=True)` | 0.178 秒 |

GPU と CPU は 2e-14 まで一致し、目的関数は同じ格子上で scikit-learn の
`lasso_path` と 3e-17 の範囲で一致します。

## Elastic net と Ridge

同じ Gram 行列は、さらに 2 つの推定器にも使えます。`fit_path` と
`fit_path_batch` は `l1_ratio` (scikit-learn の混合パラメータ) を
取ります。罰則の L2 側は更新の分母にしか入らないので、elastic net は
GPU 経路も含めて同一の機構の上で走り、`l1_ratio=1` はビット単位で
lasso と同じです。

`CovRidge` は閉形式です。対称固有分解を 1 回行えば、以降 alpha
あたり O(p^2) で済むので、数千個の alpha も 1 個分の費用で出ます。
目的関数は scikit-learn の `Ridge` (`fit_intercept=False`。lasso と
違い行数では割りません) と一致し、機械精度まで合います。

```python
path = model.fit_path(lambdas, l1_ratio=0.5)   # elastic net
ridge = CovRidge(X, y)
betas = ridge.fit_path(ridge.alpha_grid())     # ridge のパス全体
```

実測(リポジトリの `bench/ridge-enet-compare.py`: AR(1) 設計、罰則 20 本、
Gram 行列をどこで作るにせよそれ込みの呼び出し全体、1 コア、3 回の最良値):

| n × p                                        | 1,800 × 200 | 5,000 × 1000 | 100,000 × 200 | 100,000 × 500 |
|----------------------------------------------|-------------|--------------|---------------|---------------|
| elastic net、`CovLasso.fit_path(l1_ratio=0.5)`、tol 1e-8 | 0.007 秒 | 0.092 秒 | 0.11 秒    | 0.40 秒       |
| elastic net、sklearn `enet_path(precompute=True)`、tol 1e-4 | 0.005 秒 | 0.099 秒 | 0.23 秒 | 0.74 秒       |
| ridge、`CovRidge.fit_path(alphas)`           | 0.004 秒    | 0.21 秒      | 0.10 秒       | 0.41 秒       |
| ridge、sklearn `Ridge(alpha).fit` を alpha ごと | 0.060 秒 | 2.05 秒      | 3.37 秒       | 11.2 秒       |
| ridge、sklearn `RidgeCV(alphas)`(LOO のパス) | 0.093 秒   | 3.40 秒      | 5.38 秒       | 19.0 秒       |

elastic net は両側とも同じ座標降下なので、2 行の差は掃引ではなく Gram と
暖かいパスの分です: 小さい n では同等、10 万行で 1.8〜2.2 倍、こちらは
厳しい参照との差が 2e-10 以内、scikit-learn の既定の許容誤差では 6e-4 以内。
ridge の行はパス全体を、利用者が書く形 — alpha ごとに `Ridge.fit`、毎回
X'X を作って解く O(np² + p³) — と比べているので、差はパスの差です:
10〜33 倍、一致は 1e-14。`RidgeCV` は規模感のために置いたもの(パスを返さず
LOO で alpha を 1 つ選ぶ)。どちらも GPU では走りません。ridge は固有分解
1 回、elastic net の掃引は lasso のものです。elastic net の GPU 格子は
`fit_path_batch(l1_ratio=..)` です。

## Bayesian ridge

`CovBayesianRidge` は scikit-learn の `BayesianRidge` と同じモデル・同じ
既定値・同じ反復(雑音の精度 `alpha_` と重みの精度 `lambda_` を MacKay の
式で更新し、事後平均の動きが `tol` 未満で終了)で、線形代数だけを Gram
行列の固有基底に移したものです。scikit-learn は X の SVD を 1 回取り、
反復のたびに二乗誤差のためにもう一度 X を掛けます。こちらは X を X'X
(n <= p なら X X')として 1 回だけ使い、固有分解を 1 回取ったあとは、
事後平均・そのノルム・二乗誤差がすべて固有値についての和になり、1 反復
O(p) です。`sigma_`(事後共分散)と `predict(return_std=True)` も
scikit-learn と同じように使えます。

```python
from scm2cpp_lasso import CovBayesianRidge
m = CovBayesianRidge().fit(X, y)          # sklearn と同じく fit_intercept=True
mean, std = m.predict(X_new, return_std=True)
```

測定(リポジトリの `bench/bayesian-ridge-compare.py`。ガウス設計、疎な
真値と雑音、`sigma_` 込みの fit 全体、1 コア、3 回の最良値、sklearn 1.9.1):

| n × p | `CovBayesianRidge` | sklearn `BayesianRidge` | 倍率 | 反復回数(両者) | 係数の最大差 |
|---|---|---|---|---|---|
| 1,800 × 200 | 0.005 秒 | 0.026 秒 | 5.2 倍 | 3 | 3.6e-15 |
| 5,000 × 1000 | 0.257 秒 | 1.231 秒 | 4.8 倍 | 4 | 6.7e-15 |
| 100,000 × 200 | 0.126 秒 | 3.495 秒 | 27.8 倍 | 3 | 2.8e-14 |
| 100,000 × 500 | 0.475 秒 | 8.909 秒 | 18.8 倍 | 3 | 1.6e-14 |
| 500 × 5000 | 0.662 秒 | 8.689 秒 | 13.1 倍 | 71 | 1.7e-15 |

反復回数は同じで係数も丸め誤差の範囲で一致するので、差は線形代数だけから
来ています。縦長の X の完全な SVD に対して BLAS の積 1 回の X'X で済み、
反復の中で X を通らないからです。500 × 5000 では scikit-learn は `sigma_`
のために 5000 × 5000 の完全な SVD を取りますが、こちらは Woodbury の恒等式で
500 × 500 のカーネル側から `sigma_` を作ります。この推定器は翻訳したコード
ではなく numpy で書いたもので、固有分解はどちらも LAPACK です。

## 分類器と SVR: `LinearSVM`、`KernelSVM`、`LinearSVR`、`KernelSVR`、`L1LogisticRegression`

3 つの分類器と 2 つの回帰です。どれも scikit-learn が走らせるアルゴリズムを Scheme の
サブセットでそのまま書き、普通に翻訳したものです(導出はしていません。
C++ は `_generated/classifiers*` にコミットしてあります):

| クラス | アルゴリズム | 対応する scikit-learn |
|---|---|---|
| `LinearSVM` | liblinear の hinge 損失の双対座標降下(乱択順、shrinking) | `LinearSVC(loss="hinge", dual=True, fit_intercept=False)` |
| `KernelSVM` | libsvm の SMO(WSS3、shrinking、切片)をカーネル行列全体の上で | `SVC`(`kernel="rbf"`、`"linear"`、`"precomputed"`) |
| `L1LogisticRegression` | liblinear の newGLMNET(座標降下の上の Newton 法と直線探索) | `LogisticRegression(l1_ratio=1, solver="liblinear", fit_intercept=False)` |
| `LinearSVR` | liblinear の epsilon 不感損失の双対座標降下(乱択順、shrinking) | `LinearSVR(loss="epsilon_insensitive", dual=True, fit_intercept=False)` |
| `KernelSVR` | `KernelSVM` と同じ SMO を libsvm の epsilon-SVR の形(2n 変数)で | `SVR`(`kernel="rbf"`、`"linear"`、`"precomputed"`) |

```python
from scm2cpp_lasso import LinearSVM, KernelSVM, L1LogisticRegression
LinearSVM(C=1.0).fit(X, y).predict(X_new)
KernelSVM(C=1.0, gamma="scale").fit(X, y).decision_function(X_new)
L1LogisticRegression(C=0.1).fit(X, y).predict_proba(X_new)
```

分類器は 2 クラスを受け付けます(`classes_` の 2 番目が正のクラス)。`tol` と
`max_iter` の意味は scikit-learn と同じです。`KernelSVM` と `KernelSVR` はカーネル行列を
numpy で作って全体を持ちます(n × n の double、n = 10,000 で 800 MB)。
`SVC` は行を必要なときにキャッシュ経由で計算するので、ここが代償です。

測定はこのディレクトリの `check-classifiers.py` です。両側とも同じ問題・
同じ停止規則、1 コア、3 回の最良値、sklearn 1.9.1、load average 2 未満。
こちらの時間には、カーネル行列の作成(`KernelSVM`)や X の列への転置
(`L1LogisticRegression`)を含みます:

| 問題 | ours | scikit-learn | 倍率 | 目的関数(ours / sklearn) | 予測の一致 |
|---|---|---|---|---|---|
| `LinearSVM`、5,000 × 200 | 0.379 s | 0.598 s | 1.6 倍 | 1541.06 / 1541.29 | 99.5% |
| `LinearSVM`、100,000 × 200 | 23.0 s | 41.7 s | 1.8 倍 | 34503.5 / 34500.7 | 98.9% |
| `LinearSVM`、2,000 × 20,000 | 0.975 s | 1.894 s | 1.9 倍 | 0.052484 / 0.052428 | 100% |
| `KernelSVM` rbf、2,000 × 50 | 0.068 s | 0.139 s(precomputed 0.081 s) | 2.1 倍(1.2 倍) | -1065.5026 / -1065.5026 | 100% |
| `KernelSVM` rbf、5,000 × 50 | 0.501 s | 1.032 s(precomputed 0.588 s) | 2.1 倍(1.2 倍) | -2628.1422 / -2628.1422 | 100% |
| `KernelSVM` rbf、10,000 × 50 | 2.12 s | 4.15 s(precomputed 2.61 s) | 2.0 倍(1.2 倍) | -4994.9982 / -4994.9982 | 100% |
| `L1LogisticRegression`、5,000 × 200、C=0.1 | 0.064 s | 0.103 s | 1.6 倍 | 61.676698 / 61.676708 | 100% |
| `L1LogisticRegression`、20,000 × 500、C=0.05 | 1.20 s | 2.23 s | 1.9 倍 | 106.77913 / 106.77915 | 100% |
| `L1LogisticRegression`、100,000 × 200、C=0.05 | 9.06 s | 18.7 s | 2.1 倍 | 349.61154 / 349.61216 | 100% |

回帰の 2 つ(同じスクリプト、C = 1、epsilon 0.1):

| 問題 | ours | scikit-learn | 倍率 | 一致 |
|---|---|---|---|---|
| `LinearSVR`、5,000 × 200 | 1.32 s | 2.53 s | 1.9 倍 | 両方 1,000 掃引の上限で停止。目的関数 779.99 / 790.72 |
| `LinearSVR`、20,000 × 500 | 22.1 s | 36.6 s | 1.7 倍 | 両方上限で停止。目的関数 3741.4 / 3712.2 |
| `KernelSVR` rbf、1,000 × 10 | 0.023 s | 0.043 s | 1.9 倍 | 反復 2,172 / 2,177、予測の差 4e-4 以内 |
| `KernelSVR` rbf、3,000 × 10 | 0.246 s | 0.332 s | 1.3 倍 | 反復 7,471 / 7,581、5e-4 以内 |
| `KernelSVR` rbf、6,000 × 10 | 1.18 s | 1.38 s | 1.2 倍 | 反復 16,805 / 16,630、5e-4 以内 |

このデータの `LinearSVR` は、どちらも 1,000 掃引で許容誤差に届かず、上限の
時点では乱択順の違いだけで目的関数が約 1% 動きます(scikit-learn 自身も種を
変えると 5,000 × 200 で 776〜789)。20,000 掃引では両方とも 728.58 に着きます。
`KernelSVR` の伸びが n とともに小さくなるのは、特徴が 10 個で libsvm にとって
カーネルの行の計算が安く、こちらは n² 個の double の行列を読むためです。
予測は scikit-learn の許容誤差の範囲で一致します。

目的関数の一致は、丸め誤差の範囲ではなく、両側の停止判定の許容誤差の
範囲です。縦長データの線形 SVM は両側とも 1,000 掃引の上限で止まるので、
そこではわずかに違う所に着き、予測が 1% 違います。速さの理由は 3 つとも
同じで、同じアルゴリズムを、ベクトル化される密なループとして走らせて
いるからです(libsvm と liblinear は疎な行を歩きます)。分類器は `-O3` と
`-fstrict-overflow` でコンパイルしています。Python のビルド引数には
`-fno-strict-overflow` が入っていて、これがあるとコンパイラは平坦な添字
`i*p + j` を帰納変数として扱えず、線形 SVM が 25% 遅くなるためです。

## NMF: `CDNMF`

`CDNMF` は、翻訳器が導出した scikit-learn の `NMF(solver="cd")` です
(Frobenius 損失、正則化なし、shuffle なし)。
`examples/kernel-only/nmf-cd.scm` は、半ステップを残差 R = X − W H で
書いていて、Gram 行列は出てきません。`--derive` は、外に出した H H' の上で
R H' をメモにし、R を作る処理をメモに分配します。そのため、コンパイルされた
半ステップは R を作らない scikit-learn の `XHt − W HHt` そのものです。
`DerivedLasso` と同じく 3 種類あり、`nmf_backend()` がどれを使うかを返します
(GPU があれば cublas、なければ blas、それもなければ loops)。

```python
from scm2cpp_lasso import CDNMF
model = CDNMF(n_components=20, random_state=0)   # sklearn と同じ init="random"
W = model.fit_transform(X)                       # H は model.components_
```

`init="random"` は scikit-learn と同じ引き方なので、同じ種なら同じ W と H
から始まります。scikit-learn の既定の `"nndsvda"` はありません。その初期値で
比べるなら、`init="custom"` で W と H を渡します。測定は
`check-classifiers.py --only nmf`。`NMF(solver="cd", init="random")` を同じ
種から、tol 1e-4、最大 200 反復、1 コア:

| n × p, k | `CDNMF` cuBLAS | `CDNMF` BLAS | sklearn | 反復 | max \|H − H_sklearn\| |
|---|---|---|---|---|---|
| 1,000 × 500, 10 | 0.441 s(0.6 倍) | 0.212 s(1.15 倍) | 0.244 s | 200 / 200 | 1.3e-13 |
| 5,000 × 2,000, 20 | 7.01 s(1.6 倍) | 8.27 s(1.36 倍) | 11.25 s | 200 / 200 | 4.1e-12 |
| 20,000 × 1,000, 30 | 16.9 s(1.8 倍) | 20.6 s(1.46 倍) | 30.1 s | 200 / 200 | 2.4e-12 |

反復の途中の値は丸め誤差の範囲で scikit-learn と同じです。cuBLAS 版は中くらいの
形から得になります。1,000 × 500 では転送の費用が積で節約する分を上回るので、
そこでは `backend="blas"` の方が速くなります。

## グラフィカル lasso と RANSAC: `CDGraphicalLasso`、`LinearRANSAC`

scikit-learn のアルゴリズムをさらに 2 つ、Scheme のサブセットでそのまま書いて
普通に翻訳したものです。

- `CDGraphicalLasso` は `GraphicalLasso(mode="cd")` です。
  `_graphical_lasso` と内側の `enet_coordinate_descent_gram` で、列ごとの
  行列とベクトルの積 2 つは dgemv です。`alpha`、`tol`、`enet_tol`、
  `max_iter`、`assume_centered` の意味は scikit-learn と同じです。
  scikit-learn の `costs_`(毎反復の log det)は計算しません。
- `LinearRANSAC` は `LinearRegression` を使う `RANSACRegressor` で、既定値も
  同じです。scikit-learn が入っていれば、部分集合を scikit-learn と同じ方法で
  引くので、同じ `random_state` なら scikit-learn と同じ当てはめになります。

```python
from scm2cpp_lasso import CDGraphicalLasso, LinearRANSAC
prec = CDGraphicalLasso(alpha=0.1).fit(X).precision_
fit = LinearRANSAC(random_state=0).fit(X, y)       # fit.coef_、fit.inlier_mask_
```

パッケージから使って測りました。1 コア、3 回の最良値で、scikit-learn と同じ
データです(グラフィカル lasso は n = 20p の AR(1) 設計で両側とも 100 反復、
RANSAC は外れ値を含む線形モデルで max_trials 1000):

| 問題 | ours | scikit-learn | 倍率 | 一致 |
|---|---|---|---|---|
| `CDGraphicalLasso`、p = 50 | 0.0069 s | 0.306 s | 44.5 倍 | 反復 100 / 100、精度行列 1.8e-14 |
| `CDGraphicalLasso`、p = 200 | 0.286 s | 1.62 s | 5.7 倍 | 精度行列 2.6e-14 |
| `CDGraphicalLasso`、p = 800 | 33.9 s | 43.8 s | 1.3 倍 | 精度行列 5.0e-14 |
| `LinearRANSAC`、10,000 × 5 | 0.0254 s | 0.0916 s | 3.6 倍 | 試行 98 / 98、インライア同じ |
| `LinearRANSAC`、100,000 × 10 | 0.153 s | 0.241 s | 1.6 倍 | 試行 97 / 97、インライア同じ |
| `LinearRANSAC`、20,000 × 20 | 0.470 s | 1.19 s | 2.5 倍 | 試行 1,000 / 1,000、インライア同じ |

どちらの差も、主に scikit-learn がコンパイル済みの処理の合間に行う Python の
処理から来ています(グラフィカル lasso の列ごとの処理と、RANSAC の試行ごとの
入力検査と当てはめ)。コンパイル済みの部分の割合が大きくなるほど差は縮みます
(p が大きいグラフィカル lasso)。

## SGD、OMP、LARS: `SGDLinearClassifier`、`SGDLinearRegressor`、`GramOMP`、`GramLars`、`GramLassoLars`

scikit-learn のアルゴリズムそのものを翻訳したものです。

- `SGDLinearClassifier` と `SGDLinearRegressor` は、既定の設定の
  `SGDClassifier` / `SGDRegressor` です。`_plain_sgd` が点を順に回ります。
  `shuffle=False` と比べると、重みはビット単位で同じです。scikit-learn の
  shuffle の乱数は再現していません。
- `GramOMP` は、Gram 行列を使う `OrthogonalMatchingPursuit` です。
  scikit-learn では n > p のときの経路ですが、ここでは常にこの経路を使います。
  X'X と X'y は dsyrk と dgemv で作ります。
- `GramLars` と `GramLassoLars` は、Gram 行列を使う `Lars` と `LassoLars`
  です。こちらも n > p のときの経路を常に使い、Gram 行列は numpy で作ります。

```python
from scm2cpp_lasso import SGDLinearClassifier, GramOMP, GramLassoLars
SGDLinearClassifier().fit(X, y).predict(X_new)
GramOMP(n_nonzero_coefs=10).fit(X, y).coef_
GramLassoLars(alpha=0.01).fit(X, y).coef_
```

どれも scikit-learn と同じ係数になります(SGD はビット単位、ほかは 1e-15
まで)。エポック数やステップ数も同じです。速さはリポジトリの README の表の
とおりで、SGD は 1.0〜3.3 倍、OMP は 1.1〜2.8 倍、LARS は 1.2〜5.0 倍です。
差が大きいのは小さい問題で、そこでは scikit-learn がステップの合間に行う
Python の処理が時間の大半を占めます。

## L2 ロジスティック回帰と Huber: `LBFGSLogisticRegression`、`LBFGSHuberRegressor`

`LogisticRegression(solver="lbfgs")`(既定の設定。2 クラスは二項、3 クラス
以上は多項)と `HuberRegressor` です。下で動く scipy の L-BFGS-B もサブセットで
書いてあります。積は、CBLAS がリンクできれば dgemm / dgemv です。

```python
from scm2cpp_lasso import LBFGSLogisticRegression, LBFGSHuberRegressor
LBFGSLogisticRegression(C=1.0).fit(X, y).predict_proba(X_new)
LBFGSHuberRegressor(epsilon=1.35).fit(X, y).coef_
```

どちらも scikit-learn と反復が 1 回ずつ一致し、係数も丸め誤差の範囲(最大
1e-13)で同じです。速さはリポジトリの README の表のとおりで、ロジスティック
回帰は 1.1〜8 倍(大きな二値問題では、両側とも 1 回の評価が行列ベクトル積
2 回なので 1 倍に近い)、Huber は 2.5〜18 倍です。

## 混合ガウス、FastICA、PCA: `EMGaussianMixture`、`ParallelFastICA`、`CovPCA`

full 共分散の `GaussianMixture`、既定の設定の `FastICA`、共分散の固有ベクトルに
よる `PCA`(scikit-learn の "covariance_eigh"。縦長の設計行列で "auto" が選ぶ
解法)です。どれも scikit-learn のアルゴリズムを翻訳したもので、積は CBLAS が
リンクできれば dgemm / dsyrk、固有値問題はサブセットで書いてあります。

```python
from scm2cpp_lasso import EMGaussianMixture, ParallelFastICA, CovPCA
EMGaussianMixture(4, random_state=0).fit(X).predict(X)   # KMeans の初期化は scikit-learn のもの
ParallelFastICA(random_state=0).fit(X).transform(X)
CovPCA(n_components=10).fit(X).components_
```

同じ `random_state` から始めれば、どれも scikit-learn と反復回数が一致し、
パラメータも丸め誤差の範囲で同じになります。速さはリポジトリの README の表の
とおりです。
- 混合ガウス: 1.6〜2.4 倍
- FastICA: 1.1〜1.4 倍
- PCA: 特徴量が 100 程度までは 1.3〜4 倍。200〜500 では 0.6〜0.8 倍で、
  LAPACK の固有値ソルバーの方が速い。

## Perceptron、ARD、LassoLarsIC、L1 線形 SVM: `SGDPerceptron`、`CovARDRegression`、`GramLassoLarsIC`、`L1LinearSVM`

- `SGDPerceptron` は `Perceptron` です。`SGDLinearClassifier` /
  `SGDLinearRegressor` は、次の設定も受け付けるようになりました。
  - `loss="perceptron"` / `"epsilon_insensitive"`
  - `learning_rate="constant"` / `"pa1"` / `"pa2"`
  - `penalty=None`

  これで、scikit-learn が passive-aggressive の推定器の置き換えとしている設定が
  再現できます。どれも shuffle=False で走ります。
- `CovARDRegression` は `ARDRegression`(n >= p)です。既定の `hoist=True` では、
  残っている特徴の Gram を、1 回だけ作った X'X から取り出します。
  `hoist=False` では scikit-learn と同じく毎回作り直します。
- `GramLassoLarsIC` は `LassoLarsIC` です。lasso の経路全体を翻訳した LARS で
  求め、情報量規準は Gram から計算します。
- `L1LinearSVM` は `LinearSVC(penalty="l1", dual=False)` で、liblinear の
  solve_l1r_l2_svc です。座標の順番を別の乱数で作るので、scikit-learn との
  一致は収束許容誤差の範囲です。

```python
from scm2cpp_lasso import SGDPerceptron, CovARDRegression, GramLassoLarsIC, L1LinearSVM
SGDPerceptron().fit(X, y)
CovARDRegression().fit(X, y).coef_
GramLassoLarsIC("bic").fit(X, y).alpha_
L1LinearSVM(C=1.0).fit(X, y).coef_
```

速さはリポジトリの README の表のとおりです。
- SGD: 1.2〜3 倍
- ARD: 1.6〜1.9 倍(Gram を巻き上げると 3 倍)
- LassoLarsIC: 8〜20 倍
- L1 SVM: 1.1〜1.5 倍

## GLM、CV、Theil-Sen: `LBFGSPoissonRegressor`、`LBFGSGammaRegressor`、`LBFGSTweedieRegressor`、`LBFGSLogisticRegressionCV`、`GramLarsCV`、`GramLassoLarsCV`、`GramOMPCV`、`WeiszfeldTheilSen`

- GLM は `PoissonRegressor`、`GammaRegressor`、`TweedieRegressor`
  (solver "lbfgs")です。`LBFGSLogisticRegression` と同じ L-BFGS-B で解きます。
- CV のクラスは `LogisticRegressionCV`、`LarsCV`、`LassoLarsCV`、
  `OrthogonalMatchingPursuitCV` を再現します。分割(KFold / StratifiedKFold、
  shuffle なし)、C・alpha・列数の選び方、全データでの解き直しまで同じです。
- `WeiszfeldTheilSen` は、scikit-learn と同じ部分集合で動く `TheilSenRegressor`
  です。

```python
from scm2cpp_lasso import LBFGSPoissonRegressor, LBFGSLogisticRegressionCV, GramLassoLarsCV
LBFGSPoissonRegressor(alpha=1e-3).fit(X, counts).predict(X_new)
LBFGSLogisticRegressionCV().fit(X, labels).C_
GramLassoLarsCV().fit(X, y).alpha_
```

速さはリポジトリの README の表のとおりです。
- GLM: 1.1〜6 倍
- CV: 1.6〜6.6 倍
- Theil-Sen: 1.3〜1.8 倍(部分集合の抽選に時間の大半がかかる)

## 特徴選択: `f_regression`、`f_classif`、`SelectKBest`、`SelectPercentile`、`GramRFE`

scikit-learn の単変量 F 統計量と、それを使う選択器、`Ridge` /
`LinearRegression` を使う `RFE` を翻訳したものです。`f_regression` は n × q の
目的変数の配列も受け付けます。q 個の結果を 1 回の行列積で求め、デバイスが
あればデバイスで計算します。

```python
from scm2cpp_lasso import SelectKBest, GramRFE, f_regression
SelectKBest("f_regression", k=20).fit(X, y).get_support()
GramRFE(alpha=1.0, n_features_to_select=10).fit(X, y).ranking_
F, p = f_regression(X, Y)          # Y: n x q、すべての目的変数をまとめて
```

スコア、順位、選ばれる特徴は scikit-learn と同じです。
- RFE: 80〜1,000 倍。各回の当てはめ直しの代わりに、Gram 行列 1 つと、
  縮めていくコレスキー因子 1 つで済ませます。
- 多数の目的変数の f_regression: 30〜50 倍。

Gram 経路の推定器(`GramLassoLarsIC`、`GramLarsCV`、`GramLassoLarsCV`、
`GramLars`、`GramLassoLars`、`CovPCA`)は、デバイスがあれば大きな X'X を
デバイスで作ります。`SCM2CPP_NO_DEVICE=1` を設定すると、すべて CPU で動きます。

## Intel の sklearnex との比較

sklearnex(scikit-learn-intelex 2026.2、中身は oneDAL)は、scikit-learn の一部の
推定器を自前の実装に置き換えます。`bench/sklearnex-compare.py` は、このパッケージに
対応するものがある推定器を測ります。sklearnex の推定器は差し替え(patch)ではなく
直接 import するので、同じプロセスで scikit-learn 本体も測れます。比は scikit-learn
または sklearnex の時間を、このパッケージの速い方(CPU 版、またはデバイスが応えれば
デバイス版)で割ったものです。ロードアベレージは 8〜11 で、時間には数十 % の揺れが
あります。

| 推定器、n x p | 反復(sk / sklearnex / 当方) | scikit-learn 比、1 コア | sklearnex 比、1 コア | sklearnex 比、20 コア |
|---|---|---|---|---|
| LogisticRegression、200,000 x 100 | 6 / 12 / 6 | 10.6 倍(デバイス) | 8.4 倍(デバイス) | 4.4 倍(デバイス)。CPU では 0.5 倍 |
| Ridge(alpha 1)、200,000 x 200 | - | 2.1 倍 | 1.2 倍 | 0.3 倍 |
| PCA(10 成分)、100,000 x 50 | - | 1.5 倍 | 2.4 倍 | 1.7 倍 |
| PCA(10 成分)、50,000 x 500 | - | 1.1 倍 | 1.4 倍 | 0.5 倍 |
| SVC(rbf)、5,000 x 20 | 4,858 / 7 / 4,882 | 1.2 倍 | 1.4 倍 | 0.5 倍 |
| SVR(rbf)、5,000 x 20 | 12,821 / 10 / 12,824 | 1.3 倍 | 1.4 倍 | 0.4 倍 |
| RFE(Ridge)、200 から 20 を残す、20,000 x 200 | - | 216 倍 | 128 倍 | 78 倍 |

1 コア同士なら、どれもこのパッケージが速いです。sklearnex は既定で全コアを使い、
このパッケージのカーネルは 1 スレッドなので、20 コアでは Ridge、大きい PCA、SVM で
sklearnex が速くなります。それでも上回るのは、デバイス版(ロジスティック回帰)と、
仕事の量そのものが少ないアルゴリズム(RFE: Gram を一度だけ作り、1 本落とすたびに
Cholesky 因子を更新する。scikit-learn は毎回当てはめ直す)です。sklearnex は
scikit-learn と同じ計算ではありません。ロジスティック回帰の反復は scikit-learn の
6 回に対して 12 回で、係数は scikit-learn と 6e-3 ずれます(このパッケージは 4e-15
まで一致)。SVM も反復回数の数え方が違います。この版の sklearnex は lasso を
速くしないので、上の lasso の表は scikit-learn だけとの比較のままです。

## GPU 版

インストール時に CUDA ツールキットがあれば、次のクラスに、同じ Scheme を
`--cuda` で翻訳した版(`libscm2cpp_gpu.so`)も付きます。
- `ParallelFastICA`、`EMGaussianMixture`
- `LBFGSLogisticRegression`、`LBFGSLogisticRegressionCV`、`LBFGSHuberRegressor`
- `LBFGS*` の GLM

ループは CUDA カーネル、積は cuBLAS で、配列はデバイスに置いたままです。
デバイスがあり、データが 100 万要素以上のときに使われます。反復回数と結果は、
CPU 版と末尾の桁まで同じです。

scikit-learn と比べた速さ(リポジトリの README の表):
- L-BFGS 系: 10〜22 倍
- FastICA: 6.7 倍
- 混合ガウス、LogisticRegressionCV: 3 倍

`SCM2CPP_NO_DEVICE=1` を設定すると、すべて CPU で動きます。

## L1 付きロジスティック回帰

`CovLogistic` は L1 罰則付きロジスティック回帰を優越化 (majorization)
で解きます。ロジスティックのヘッセ行列は X'X/4 で抑えられるので、
二次の項は同じ Gram 行列を一度固定するだけでよく、外側の各反復は
勾配 1 パスの後、lasso と同じ座標降下に優越化子を渡します。目的関数は
scikit-learn の `LogisticRegression(penalty="l1", fit_intercept=False)`
(`C = 1/(n lam)`) と 9e-15 まで一致します。

## Group lasso

`CovGroupLasso` はグループ全体に罰則を掛けます — `lam * sum_g sqrt(|g|)
||b_g||` — ので、相関した特徴量は一緒に入り、一緒に消えます。同じ Gram
機構の上のブロック座標降下で、各ブロック訪問はブロック Gram を最大
固有値 (一度だけ計算) で優越した近接ステップ 1 回、単調に降下します。
サイズ 1 のグループでは lasso に厳密に退化し (sklearn と 9e-16 で照合)、
収束点ではグループ KKT 条件が 2e-12 まで成り立ちます。

## GPU でのブートストラップ

`bootstrap` はペアブートストラップの再標本を引いて、1 つの lambda で
全部を当てはめ直します。各再標本の Gram 行列は多重度カウント `m` に
対する `X' diag(m) X` で、`Xs = diag(sqrt m) X` として `Xs' Xs` の形に
書き、numpy が対称 rank-k 積 (`dsyrk`、`X' (diag(m) X)` の半分の flops)
に渡すようにしています — BLAS 呼び出し 1 回。問題どうしは独立なので、
降下は 1 つのバッチとして走ります。GPU では再標本ごとにスレッドの
ブロック 1 つ、それぞれが自分の Gram 行列を読みます。コストは積の
側で、n=5000, p=1000 の再標本 100 本は一般の積で 18.1 s、`dsyrk` で
11.2 s でした (降下込み)。

```python
betas = model.bootstrap(lam, n_boot=500, seed=0)   # (500, p)
freq = (abs(betas) > 1e-9).mean(axis=0)            # 選択頻度
```

モデルを `X, y` から構築した場合に限り使えます (Gram 行列だけでは
行の再標本化ができないため)。GPU と CPU は機械精度で一致します。

## 構造を持つ設計行列

設計行列に構造があるなら、X'X を一般的なやり方で作るのは筋の悪い手です。
`kernel` は翻訳された関数を直接公開しており、
[`scm2cpp-tfs`](https://pypi.org/project/scm2cpp-tfs/) は移動平均の設計行列に
対してまさにそれを行います。系列の前置和から O(n p) で Gram 行列を作り、
設計行列は決して作りません。あのパッケージは単独で完結します — この降下の
複製を自分で持つので — どちらも他方を入れることはありません。

## これがどこから来たか

このパッケージがコンパイルする C++ は scm2cpp リポジトリの
`python/scm2cpp-lasso/` にコミットされています。`CovLasso` と残りは
`examples/kernel-only/lasso-cov.scm` — Gram のレベルで手書きした
covariance-update の掃引 — の翻訳の上で、`DerivedLasso` は
`examples/kernel-only/lasso-design.scm` — numpy が持つままの X の上の素朴な
残差形の降下 — の翻訳の上で走り、後者は翻訳器の `--derive --blas` が同じ covariance 形をそこから
導出したものです。2 つは同じ `dsyrk` の上の同じ掃引で、時間も同じです。
Scheme を変えた後にコミット済みの C++ を作り直すには `regenerate.sh` を
走らせてください。その手順だけが Racket を必要とします。

## ライセンス

MIT。scm2cpp と同じです。

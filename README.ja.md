# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml) [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/niitsuma/scm2cpp/blob/master/notebooks/compare-sklearn.ipynb)

*[English version](README.md) · [中文](README.zh.md)*

Scm2Cpp は Scheme の部分集合を、人が読んで編集できる C++ へ翻訳します。
これを使って scikit-learn の機械学習アルゴリズムを素朴に書き、高速化しました。
翻訳器は素朴な形から速い形を導出し(座標降下から Gram 行列を外へ出す、ループ
不変な積を一度だけ作る)、積を BLAS か cuBLAS に渡し、並列なループを CUDA
カーネルにします。推定器は PyPI に `scm2cpp-learn` としてあり(0.17.0 までは `scm2cpp-lasso`。
その名前でも入ります)、Linux・macOS・Windows 向けには
コンパイル済みの wheel があります(コンパイラも Racket も不要)。

## 高速化した機械学習アルゴリズム

どれも scikit-learn と同じアルゴリズムを部分集合で書いたもので、反復回数と
結果を scikit-learn と突き合わせてあります。時間は 1 コアの scikit-learn との比
(i9-10900X、デバイスの行は RTX 4090、scikit-learn 1.9)で、条件は右端の節に
あります。

| アルゴリズム、n x p | `scm2cpp_learn` のクラス | scikit-learn 比 | 方法 | 節 |
|---|---|---|---|---|
| Lasso、4,096 個の罰則をそれぞれゼロから、1,800 x 200 | `CovLasso`(`fit_path_batch`) | 1 コアで 16 倍、GPU で 340 倍(許容誤差は当方 1e-8、先方 1e-4) | Gram 行列の上の降下 | [例: 速い lasso](docs/lasso.ja.md#例-速い-lasso--scheme-から-pipそして-gpu-へ) |
| Lasso のパス、罰則 20 個、100,000 x 500 | `DerivedLasso`(`fit_path`) | 6.7 倍 | 素朴な降下から導出(`--derive --cublas`) | [最初の例: lasso](#最初の例-lasso) |
| RFE(LinearRegression)、20,000 x 500 | `GramRFE(0.0, ..)` | 1,047 倍 | Gram と、1 本落とすごとに更新する Cholesky 因子 | [F 統計量と RFE による特徴選択](docs/benchmarks.ja.md#f-統計量と-rfe-による特徴選択デバイス上の-gram) |
| f_regression、目的変数 100 個、20,000 x 1,000 | `f_regression` | 49 倍 | デバイス上の積 1 回 | [F 統計量と RFE による特徴選択](docs/benchmarks.ja.md#f-統計量と-rfe-による特徴選択デバイス上の-gram) |
| RidgeCV、alpha 50 個、20,000 x 500 | `GramRidgeCV` | 29 倍 | 固有分解 1 回、全 alpha の 1 個抜き誤差を積 2 回で | [固有分解 1 回の RidgeCV](docs/benchmarks.ja.md#固有分解-1-回の-ridgecv) |
| KernelPCA(rbf)、5 成分、6,000 x 20 | `GramKernelPCA` | 3.5 倍 | dgemm による部分空間反復(scikit-learn は ARPACK) | [部分空間反復の KernelPCA](docs/benchmarks.ja.md#部分空間反復の-kernelpca) |
| LinearDiscriminantAnalysis、200,000 x 100、5 クラス | `GramLDA` | 52 倍 | svd ソルバの n x p の SVD を Gram の p x p の固有値問題に | [Gram 行列からの LDA](docs/benchmarks.ja.md#gram-行列からの-lda) |
| TruncatedSVD、10 成分、200,000 x 100 | `GramTruncatedSVD` | 5.4 倍(arpack 比 20 倍) | X'X からの厳密な SVD(scikit-learn の既定は近似) | [Gram 行列からの TruncatedSVD](docs/benchmarks.ja.md#gram-行列からの-truncatedsvd) |
| CCA / PLSRegression、50,000 x 500 -> 10 | `GramCCA` / `GramPLSRegression` | 109 倍 / 61 倍 | X'X、X'Y、Y'Y の上の NIPALS(行は 1 回だけ読む) | [交差積の上の PLS と CCA](docs/benchmarks.ja.md#交差積の上の-pls-と-cca) |
| GraphicalLasso、p = 50 | `CDGraphicalLasso` | 45 倍 | `--blas` | [GraphicalLasso、KMeans、RANSAC](docs/benchmarks.ja.md#graphicallassokmeansransac-と-sklearn-の比較) |
| HuberRegressor / LogisticRegression / PoissonRegressor、200,000 x 100 | `LBFGSHuberRegressor` / `LBFGSLogisticRegression` / `LBFGSPoissonRegressor` | 22 倍 / 15 倍 / 10 倍 | L-BFGS-B、`--cuda` | [翻訳器が出す GPU カーネル](docs/benchmarks.ja.md#翻訳器が出す-gpu-カーネル--cuda) |
| LassoLarsIC、200,000 x 100 | `GramLassoLarsIC` | 20 倍 | 規準を Gram から | [Perceptron、passive-aggressive、ARD、LassoLarsIC](docs/benchmarks.ja.md#perceptronpassive-aggressiveardlassolarsicl1-の線形-svm) |
| FastICA / GaussianMixture、200,000 x 20 | `ParallelFastICA` / `EMGaussianMixture` | 6.7 倍 / 3.1 倍 | `--cuda` | [翻訳器が出す GPU カーネル](docs/benchmarks.ja.md#翻訳器が出す-gpu-カーネル--cuda) |
| LogisticRegressionCV、2,000 x 20 / LarsCV、2,000 x 50 | `LBFGSLogisticRegressionCV` / `GramLarsCV` | 6.6 倍 / 6.6 倍 | 1 つの Gram の上の fold、暖かい開始 | [GLM、交差検証つきの推定器](docs/benchmarks.ja.md#glm交差検証つきの推定器theil-sen) |
| ARDRegression、20,000 x 100 | `CovARDRegression` | 3.1 倍 | X'X を一度だけ(`--derive` が導出する) | [ループ不変の積の導出](docs/benchmarks.ja.md#ループ不変の積の導出) |
| LinearSVC、100,000 x 200 | `LinearSVM` | 1.9 倍 | liblinear のソルバを部分集合で | [SVM と sklearn の比較](docs/benchmarks.ja.md#svm-と-sklearn-の比較) |
| NMF (cd)、20,000 x 1,000、30 | `CDNMF` | 1.8 倍 | 導出(`--derive --cublas`) | [NMF の導出](docs/benchmarks.ja.md#nmf-の導出と-sklearn-の比較) |

### scikit-learn の推定器の代わりに使う

ほとんどのクラスは、scikit-learn の推定器と同じ名前の引数(その一部)を取り、
`fit` / `predict` / `transform`、`coef_`、`n_iter_` なども同じなので、import を
変えるだけで差し替えられます:

```python
from scm2cpp_learn import LBFGSLogisticRegression as LogisticRegression

clf = LogisticRegression(C=1.0).fit(X, y)   # scikit-learn と同じ反復回数と係数
```

違うものもあります。`CovLasso`、`CovRidge`、`DerivedLasso` はデータをコンストラクタで
受け取り、罰則の格子をまとめて解きます(`fit_path` / `fit_path_batch`。scikit-learn
では `fit_intercept=False` の `Lasso(alpha=a).fit` を罰則ごとに繰り返す形です)。
`GramRFE` は推定器ではなくリッジの罰則を取ります(`RFE(Ridge(alpha=1.0),
n_features_to_select=20)` に対して `GramRFE(1.0, n_features_to_select=20)`、
`LinearRegression` なら `alpha=0`)。全クラスと対応する scikit-learn の推定器は、
パッケージの README の[推定器の一覧](python/scm2cpp-learn/README.ja.md#推定器の一覧)に
あります。

**scikit-learn との互換性。** 0.14.0 から推定器は scikit-learn の `BaseEstimator` と
mixin を継承します(scikit-learn 自体は任意の依存のまま)。`clone`、`GridSearchCV`、
`Pipeline`、`cross_val_score` がそのまま使え、`fit(X, y)` を持つ 44 本すべてが
`check_estimator` を通ります。データをコンストラクタで受け取るクラスには、それぞれ
`fit(X, y)` 形が並んでいます(`CovLasso` には `GramLasso`、`DerivedLasso` には
`DesignLasso` など)。代償は入力の検査で、1 呼び出しあたり約 10 us から
X を 1 回なめる分までです。測定はパッケージの README の
[互換性の節](python/scm2cpp-learn/README.ja.md#scikit-learn-との互換性)にあります。

### インストール(Python パッケージ)

```console
$ pip install scm2cpp-learn
```

| 環境 | pip が入れるもの |
|---|---|
| Linux x86_64(glibc 2.28 以降) | wheel(OpenBLAS 同梱) |
| macOS 14 以降、Apple シリコン | wheel(OpenBLAS 同梱) |
| Windows x86_64 | wheel(BLAS なしのループ版: 答えは同じ、積は遅い) |
| それ以外(Linux aarch64、Intel Mac、musl) | sdist をその場でビルド: C++17 コンパイラが必要 |

ライブラリは ctypes で読み込むので、1 つの wheel が Python 3.8 以降のどの版でも
動きます。各 wheel は Python 3.12 で入れて検査しており、Linux 版は 3.13 と 3.14 でも
確かめています。wheel に GPU のコードは入っていません。CUDA 版は、`nvcc` がパスに
ある機械で sdist から入れてください(`pip install --no-binary scm2cpp-learn
scm2cpp-learn`)。翻訳器そのものの導入は [docs/translator.ja.md](docs/translator.ja.md#インストール) にあります。

### Intel の sklearnex との比較

sklearnex(scikit-learn-intelex)も同じ推定器のいくつかを速くします。1 コア同士なら、
Ridge を除く比べたすべて(LogisticRegression、PCA、SVC、SVR、RFE(Ridge))でこのパッケージが
速いです(1.4〜106 倍。Ridge は 0.8 倍)。双方に 20 コアを使わせると(このパッケージの
ループは OpenMP、積は MKL)、Ridge(2.3 倍)、PCA(1.4〜1.6 倍)、デバイス版の
ロジスティック回帰(1.8 倍)、RFE(116 倍)で上回り、CPU 版のロジスティック回帰は
ほぼ互角、SVM では負けます(0.4〜0.5 倍。SMO は逐次のため)。sklearnex は
scikit-learn と同じ計算ではありません(L-BFGS の反復が scikit-learn の 6 回に対して
12 回、係数が 6e-3 ずれる)が、このパッケージは同じです。sklearnex に lasso はありません。
表と条件は[パッケージの README](python/scm2cpp-learn/README.ja.md#intel-の-sklearnex-との比較)にあります。

Colab の機械でこの比較をワンクリックで再現するには、冒頭のバッジから
`notebooks/compare-sklearn.ipynb` を開いてください(CPU ランタイムなら wheel を、
GPU ランタイムなら CUDA 版もビルドして入れます)。

すべてが速いわけではありません。50,000 x 500 の PCA や大きな n の KMeans は
scikit-learn と同じかそれより遅く、それぞれの節にそう書いてあります。

## 最初の例: lasso

`pip install scm2cpp-learn` して
`DerivedLasso(X, y).fit_path(lambdas)` を呼ぶと、翻訳器が*導出した* C++ の
lasso が走ります。元は素朴な残差形の座標降下
(`examples/kernel-only/lasso-design.scm`、numpy が持つままの X の上の平坦な
ループ、Gram 行列はどこにもない)で、`--derive` がそれを罰則パスの前に
Gram 行列を持ち上げた covariance 形に変え、`--blas` / `--cublas` が 3 つの
積を BLAS か cuBLAS に渡します。Gram のレベルで手書きした部分はなく、
numpy 側の準備もありません。RTX 4090 の cuBLAS 版は 20 本の罰則パスを
5,000 × 1,000 / 100,000 × 200 / 100,000 × 500 で 0.024 / 0.052 / 0.11 秒で
解き、scikit-learn の `lasso_path(precompute=True)`(既定の許容誤差、1 コア)の
0.100 / 0.236 / 0.759 秒に対して 4.2 倍・4.5 倍・6.7 倍(scikit-learn に
BLAS 20 スレッドを与えても 2.2 倍・4.5 倍・4.0 倍。スケールするのは Gram の
積だけなので)。CPU 版は隣の手書き `CovLasso` と同時間です。表・条件・厳しい参照解との差は
`python/scm2cpp-learn/README.md` にあります。導出の規則を発火順に、コードへのリンク付きで
まとめたものが `DERIVATION.ja.md` です。

## 翻訳の見た目

機械のためだけの C を吐く従来の Scheme コンパイラと違い、Scm2Cpp は Scheme
の値に実行時表現を与えません。整数は `int` に、ベクタは
`std::array<double,1025>` に、`(car x)` は `car(x)` になります。型は
プログラム全体の推論から決まり、推論で確定できなかったものが C++ の
テンプレート引数になります。

```scheme
(define (square x) (* x x))
(define (average x y) (/ (+ x y) 2.0))
(define (improve guess x) (average guess (/ x guess)))
```

は次のようになります。

```cpp
double square( double x )                 { return (x*x) ; }
double average( double x, double y )      { return ((x+y)/2.0) ; }
double improve( double guess, double x )  { return average(guess,double((x/guess))) ; }
```

## 文書

- [docs/lasso.ja.md](docs/lasso.ja.md) - lasso の詳細: カーネル、pip で入る他の lasso
  との比較、交差検証、GPU バッチ、メモリ、Python からの呼び方
- [docs/benchmarks.ja.md](docs/benchmarks.ja.md) - 推定器ごとの scikit-learn との比較:
  アルゴリズム、測り方、表の全体
- [docs/translator.ja.md](docs/translator.ja.md) - 翻訳器そのもの: 導入、コマンドラインと
  オプション、Scheme の部分集合、テストスイート、Typed Racket による検査、ランタイムヘッダ
- [python/scm2cpp-learn/README.ja.md](python/scm2cpp-learn/README.ja.md) - Python
  パッケージ: 全推定器の一覧、sklearnex との比較
- `FILES.ja.md` — 全ソースファイルの役割を 1〜2 行ずつと、Racket
  モジュール間の `require` グラフ、パイプラインの段階ごとに; 変更を
  どこに置くか(英語版は `FILES.md`)
- `DERIVATION.ja.md` — `DerivedLasso` の導出: `lasso-design.scm` の
  `--derive --blas` のログに出る規則を発火順に、コードへのリンク付きで
  (英語版は `DERIVATION.md`)
- `CHANGES.ja.md` — 歴史あるコードベースへの修正の記録と、それぞれの理由
- `scribblings/scm2cpp.scrbl` — Racket から呼ぶインターフェースの手引き
  (`read-source-forms`、`scm2cpp-match-list` など)。例は生成時に評価
  されるので試験も兼ねる: `raco scribble --dest /tmp/scm2cpp-doc
  scribblings/scm2cpp.scrbl`(`PLTCOLLECTS=$PWD/vendor:` か rkanren を
  link した上で)が `scm2cpp.html` を書き、`run-tests.sh` は `doc-unit`
  として生成する
- `ideal/stream-ideal-new.cpp` — 遅延ストリームについて生成コードが取るべき
  形を手で書いたもの

## 貢献

`CONTRIBUTING.md` を参照してください。

## ライセンス

MIT ライセンス。`LICENSE` を参照してください。そこには MIT の条項だけが
あります。

いくつかのファイルは Aubrey Jaffer の Schlep と SLIB、および Paul Graham の
*On Lisp* で公表されたユーティリティに由来します。`vendor/rkanren` は同梱の
第三者ライブラリです。これらはそれぞれ独自の寛容なライセンスの下にあり、
その全文が各ファイルの冒頭に再掲されています。これらの条件は MIT の条項に
**追加される**もので、由来と派生の度合いの実測とともに `NOTICE` に記録して
あります — `LICENSE` に混ぜないのは、ライセンスファイルが素の MIT だと
一目で分かるようにするためです。再配布者は MIT の条項に加えてこれらも
守る必要があります。

## 引用

設計を記述した論文を準備中ですが、まだこのリポジトリにはありません。
公開されるまでは、リポジトリと使用したコミットを引用してください。
機械可読なメタデータは `CITATION.cff` にあります。

`tfs-` で始まる kernel(移動平均の設計、[`scm2cpp-tfs`](https://pypi.org/project/scm2cpp-tfs/))の
時系列特徴選択(temporal feature selection)は、H. Niitsuma, *An Extension of Temporal Feature Selection*, Zenodo, 2026, [doi:10.5281/zenodo.18909363](https://zenodo.org/records/18909363) に記述されています。

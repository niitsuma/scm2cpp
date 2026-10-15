# scm2cpp-lasso

*[English version](README.md)*

Gram 行列に対する座標降下による lasso。GPU 経路は任意です。ソルバは
Scheme で書かれ、[scm2cpp](https://github.com/niitsuma/scm2cpp) が C++ へ
翻訳したものです。

```console
$ pip install scm2cpp-lasso
```

インストールに必要なのは C++17 コンパイラだけです。`nvcc` がパスにあれば
バッチ GPU ソルバも併せてビルドされます。無ければパッケージは同じように
入って同じように動き、そのメソッドだけが欠けます。

100 本の候補列のうち信号を担うのは 3 本。どれかをソルバに尋ねると、
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
フィットごとの準備代だけ払います。cuML は 1 フィットの内側を並列化
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
準同点上で 1 格子点差(平均 MSE の相対差は高々 2.6e-4)で、sklearn の
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

同じ Gram 行列がもう 2 つの推定量に仕えます。`fit_path` と
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

## 分類器: `LinearSVM`、`KernelSVM`、`L1LogisticRegression`

3 つの分類器です。どれも scikit-learn が走らせるアルゴリズムを Scheme の
サブセットでそのまま書き、普通に翻訳したものです(導出はしていません。
C++ は `_generated/classifiers*` にコミットしてあります):

| クラス | アルゴリズム | 対応する scikit-learn |
|---|---|---|
| `LinearSVM` | liblinear の hinge 損失の双対座標降下(乱択順、shrinking) | `LinearSVC(loss="hinge", dual=True, fit_intercept=False)` |
| `KernelSVM` | libsvm の SMO(WSS3、shrinking、切片)をカーネル行列全体の上で | `SVC`(`kernel="rbf"`、`"linear"`、`"precomputed"`) |
| `L1LogisticRegression` | liblinear の newGLMNET(座標降下の上の Newton 法と直線探索) | `LogisticRegression(l1_ratio=1, solver="liblinear", fit_intercept=False)` |

```python
from scm2cpp_lasso import LinearSVM, KernelSVM, L1LogisticRegression
LinearSVM(C=1.0).fit(X, y).predict(X_new)
KernelSVM(C=1.0, gamma="scale").fit(X, y).decision_function(X_new)
L1LogisticRegression(C=0.1).fit(X, y).predict_proba(X_new)
```

2 クラスを受け付けます(`classes_` の 2 番目が正のクラス)。`tol` と
`max_iter` の意味は scikit-learn と同じです。`KernelSVM` はカーネル行列を
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

目的関数の一致は、丸め誤差の範囲ではなく、両側の停止判定の許容誤差の
範囲です。縦長データの線形 SVM は両側とも 1,000 掃引の上限で止まるので、
そこではわずかに違う所に着き、予測が 1% 違います。速さの理由は 3 つとも
同じで、同じアルゴリズムを、ベクトル化される密なループとして走らせて
いるからです(libsvm と liblinear は疎な行を歩きます)。分類器は `-O3` と
`-fstrict-overflow` でコンパイルしています。Python のビルド引数には
`-fno-strict-overflow` が入っていて、これがあるとコンパイラは平坦な添字
`i*p + j` を帰納変数として扱えず、線形 SVM が 25% 遅くなるためです。

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

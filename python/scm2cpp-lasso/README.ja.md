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

## pip で入る他の lasso との比較

リポジトリの `bench/lasso-compare.py` は、同じ交差検証形の格子 —
4096 個の lambda を全てゼロから、p=200、n=1800 — を `pip install` で
入る全 lasso に解かせます: scikit-learn 1.9.0、celer 0.7.4、skglm 0.5、
RAPIDS cuML 26.8。各ソルバは自身の既定許容誤差(当方は厳しい 1e-8)、
計測外の warm-up 1 回つき、cuML はデータをデバイスに置いてから計測。
最終列は最小 lambda における目的関数の当方との差です:

| ソルバ | 時間 | 目的関数の差 |
|---|---|---|
| scm2cpp-lasso、CPU 1 コア (tol 1e-8) | 0.9 秒 | 0 |
| scm2cpp-lasso、GPU、lambda 1 つに 1 スレッド | 0.2 秒 | 0 |
| sklearn `Lasso.fit` を lambda ごと | 12.5 秒 | +1.6e-09 |
| celer | 17.3 秒 | 0 |
| skglm | 16.4 秒 | +2.8e-17 |
| cuML(GPU) | 57.5 秒 | +9.1e-07 |

celer と skglm は巨大で疎な設計行列のための道具で、この規模では
フィットごとの準備代だけ払います。cuML は 1 フィットの内側を並列化
するので 1 フィットが大きいときに勝ち、この規模では起動代が支配します。
当方の GPU は lambda を跨いで並列化します — 交差検証格子が実際に
差し出す並列軸はこちらです。

`CovLassoCV` はこの機構の上の scikit-learn `LassoCV` です — 同じ格子
構成、同じ連続 fold、同じ平均 MSE 最小の選択。構造的な節約が 2 つ
あります。fold の訓練 Gram は**引き算**(Gram は行について加法的なので
G − Xf'Xf は fold 1 個分の費用)であり、Gram ができた後は**下流が
n 行に二度と触れない** — 差が n とともに開くのはこのためです。GPU では
全 fold × 全 alpha を単一起動の 1 スレッドずつにできますが、その起動は
fold の Gram を alpha ごとに複製するため、既定では複製サイズで側を選び
ます — 512 MB 以下なら CUDA、超えたら CPU の warm パス(`force_cpu` /
`force_gpu` で上書き可)。cv=5、alpha 100 個、CPU 1 コア、
sklearn 1.9.0、3 回実行の最良値:

| n | p | CPU | CUDA(強制) | sklearn `LassoCV` |
|---|---|---|---|---|
| 1,800 | 200 | 0.13 秒 | 0.20 秒 | 0.09 秒 |
| 5,000 | 1000 | 1.4 秒 | 6.0 秒 | 1.0 秒 |
| 100,000 | 200 | 0.39 秒 | 0.40 秒 | 2.1 秒 |
| 100,000 | 500 | 1.2 秒 | 1.6 秒 | 5.5 秒 |

CUDA 列は CV が GPU に差し出せるものを正直に示しています: cv × 100 =
500 個の独立問題は、複製が小さい領域で warm CPU パスと同着、複製が
GB 級になる領域で敗北します — `fit_path_batch` の数千 lambda と違い
500 スレッドではデバイスが埋まらないので、CV の勝ちは構造的節約
(Gram の引き算と warm パス)のものであって GPU のものではなく、既定が
6.0 秒のセルを踏むことはありません(ヒューリスティックがそこでは既に
CPU 側にいます)。機構が効くのは大きい n です: Gram の下流は 100,000 行
に二度と触れません。n=5,000, p=1000 では sklearn の生 X 上の降下の方が
当方の Gram 経由より本当に速い。CPU と CUDA の選ぶ alpha は全サイズで
同一(係数 1e-14 一致)。sklearn とは n=5,000 で完全一致、それ以外は
準同点上で 1 格子点差(平均 MSE の相対差は高々 2.6e-4)で、sklearn の
tol=1e-10 なら全サイズで当方の alpha を選びます。

`CovMultiTaskLasso` と `CovMultiTaskLassoCV` は同じ機構上の multitask
族です — scikit-learn の `MultiTaskLasso`、`MultiTaskElasticNet`
(`l1_ratio` 経由)、`MultiTaskLassoCV`、`MultiTaskElasticNetCV` に
対応。罰則が W の各特徴行をタスク横断で束ねるため、座標更新は行の
L2 ノルムに対するブロック軟しきい値になります。C = X'Y − GW は
単一タスクの C と全く同様にタスクごとに維持され、Gram の下流は n 行に
触れません — カーネルは同じ翻訳済み Scheme(`mt-descend`)です。
fold は独立で、降下(ctypes)も積(BLAS)も GIL を放すので、`n_jobs`
スレッドが CV を fold 横断でスケールさせます。既定は sklearn の
`n_jobs=None` と同じ逐次で、ベンチは双方 BLAS 1 スレッド固定。
プロトコルは上と同じ、タスク数 8、単発 fit は alpha = 0.1 lambda_max、
CV は両者同一の 100 alpha 格子:

| 推定器 | n | p | 当方 | 当方 `n_jobs=5` | sklearn |
|---|---|---|---|---|---|
| MultiTaskLasso | 100,000 | 200 | 0.15 秒 | -- | 0.80 秒 |
| MultiTaskLasso | 100,000 | 500 | 0.53 秒 | -- | 1.9 秒 |
| MultiTaskLassoCV | 1,800 | 200 | 1.5 秒 | 0.33 秒 | 0.51 秒 |
| MultiTaskLassoCV | 100,000 | 200 | 1.6 秒 | 0.62 秒 | 76 秒 |
| MultiTaskElasticNetCV | 1,800 | 200 | 1.6 秒 | 0.51 秒 | 1.0 秒 |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 秒 | 0.68 秒 | 164 秒 |

(`MultiTaskElasticNet` の単発 fit は `MultiTaskLasso` と同時間。)
n=1,800 の逐次 CV は sklearn より遅い — 既定 tol=1e-8 は sklearn の
1e-4 の双対ギャップ停止より多く掃引し、そのサイズでは節約できる行が
ない。n=100,000 では Gram 経路が 48 倍・100 倍先行し、絶対時間は
n=1,800 からほぼ変わりません。係数は厳しい tol で sklearn と 1e-15
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
対する `X' diag(m) X` — BLAS の積 1 回 — で、問題どうしは独立なので、
降下は 1 つのバッチとして走ります。GPU では再標本ごとに 1 スレッド、
それぞれが自分の Gram 行列を読みます。

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
`python/scm2cpp-lasso/` にコミットされており、
`examples/kernel-only/lasso-cov.scm` から翻訳したものです。同じリポジトリは
この covariance-update ソルバを素朴なソルバから有限差分によって自動導出も
します。このパッケージはその導出されたカーネルを包んだものです。Scheme を
変えた後にコミット済みの C++ を作り直すには `regenerate.sh` を走らせて
ください。その手順だけが Racket を必要とします。

## ライセンス

MIT。scm2cpp と同じです。

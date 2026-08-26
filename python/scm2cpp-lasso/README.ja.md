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

```python
import numpy as np
from scm2cpp_lasso import CovLasso, cuda_available

model = CovLasso(X, y)                      # X'X と X'y を作る
lambdas = model.lambda_grid(num=100)        # lambda_max から下へ

path = model.fit_path(lambdas)              # 暖かい開始、逐次
grid = model.fit_path_batch(lambdas)        # すべての lambda をゼロから
print("GPU:", cuda_available())
```

目的関数は scikit-learn のもの (`fit_intercept=False`) と同じです。

    (1 / 2 nobs) ||y - X b||^2 + lam ||b||_1

罰則は特徴量自身の尺度における相関と比較されるので、`lam` の有効な範囲は
データに依存します。`lambda_max()` はすべての係数をゼロに保つ最小の罰則で、
`lambda_grid()` はそこから下へ歩きます — scikit-learn と同じ構成です。
列の尺度が大きく異なる場合は先に標準化してください。このソルバは代わりに
やってはくれません。

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

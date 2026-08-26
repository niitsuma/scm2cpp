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

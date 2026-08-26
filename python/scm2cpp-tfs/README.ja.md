# scm2cpp-tfs

*[English version](README.md)*

時間的特徴選択 (temporal feature selection): 1 本の系列の移動平均に対する
lasso を、どの段階でも設計行列を作らずに行います。ソルバは Scheme で書かれ、
[scm2cpp](https://github.com/niitsuma/scm2cpp) が C++ へ翻訳したものです。

```console
$ pip install scm2cpp-tfs
```

インストールに必要なのは C++17 コンパイラだけです。`nvcc` がパスにあれば
バッチ GPU ソルバも併せてビルドされます。無ければパッケージは同じように
入って同じように動き、そのメソッドだけが欠けます。

```python
import numpy as np
from scm2cpp_tfs import TemporalLasso, cuda_available

model = TemporalLasso(series, wmax=200, nobs=1800)
lambdas = model.lambda_grid(y, num=150)     # lambda_max から下へ

path = model.fit_path(y, lambdas)           # 暖かい開始、逐次
grid = model.fit_path_batch(y, lambdas)     # すべての lambda をゼロから
beta = path[-1]

model.windows(beta)          # 残った窓長
model.predict(beta)          # 当てはめ値。設計行列なし
model.score(y, beta)         # R^2
```

## 何が作られないか

特徴量 *j* は直近 *j+1* 観測の平均です (*j* は 0..wmax-1)。それらを収める
はずの行列は、どの段階でも作られません。

* **Gram 行列**は系列の前置和から O(n p) で作られます — X を作って掛け合わせ
  れば O(n p^2) の時間と O(n p) の空間がかかります
* **降下**は座標あたり O(n) ではなく O(p) で、しかも正確に再開できるので、
  パスは暖かいまま歩け、lambda の格子はまとめて GPU に渡せます
* **予測**は窓平均を前置和から直接読み、罰則が落とした窓をすべて飛ばします。
  したがって疎な解は自分のサポートに比例した時間で予測できます。設計行列を
  先に作らねばならない numpy と比べると、p=200、n=1800 で `predict` は
  およそ 20 倍速くなります

## Elastic net と Ridge

`fit_path` と `fit_path_batch` は elastic net 用に `l1_ratio` を
取ります。同じカーネル、同じ GPU 経路の上で走り、`l1_ratio=1` は
ビット単位で lasso と同じです。`TemporalRidge` は閉形式の相方です。
同じ設計行列なしの Gram 行列に固有分解を 1 回、以降 alpha あたり
O(p^2) — 200 窓に対する 2000 個の alpha の ridge パスは数十ミリ秒で
出ます。

## lambda の選び方

罰則は特徴量自身の尺度における相関と比較されるので、有効な範囲はデータに
依存します。`lambda_max(y)` はすべての係数をゼロに保つ最小の罰則で、
`lambda_grid(y)` はそこから下へ歩きます — scikit-learn と同じ構成です。
1 本の系列の窓は自然に同じ尺度に乗ります。そうでないものを与える場合は
先に標準化してください。

## pandas と組み合わせる

`examples/pandas_demo.py` は日次のデータフレームを取り、明日の値動きを
説明する lookback 窓を答えます。

```console
$ pip install scm2cpp-tfs pandas
$ python3 pandas_demo.py
rows 1821, candidate windows 120, GPU yes
chosen lambda 4.35e-05 (9 of 120 windows kept)

selected windows (largest coefficient first); the target was built from 5 and 60:
 window  coefficient
      4       0.5273
     51      -0.1684
     24       0.1060
...
hold-out R^2: 0.2653
```

## これがどこから来たか

[scm2cpp](https://github.com/niitsuma/scm2cpp) の
`examples/kernel-only/lasso-cov.scm` と `tfs-predict.scm` を C++ へ翻訳し、
`python/scm2cpp-tfs/` にコミットしたものです。同じリポジトリは、この
covariance-update ソルバを素朴なソルバから有限差分によって自動導出もします。
Scheme を変えた後にコミット済みの C++ を作り直すには `regenerate.sh` を
走らせてください。その手順だけが Racket を必要とします。

## ライセンス

MIT。scm2cpp と同じです。

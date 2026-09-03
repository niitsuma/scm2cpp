# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml)

*[English version](README.md)*

Scm2Cpp は Scheme の部分集合を、人が読んで編集できる C++ へ翻訳します。

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

## 例: 速い lasso — Scheme から pip、そして GPU へ

このリポジトリの看板製品は lasso ソルバです。素の Scheme
(`examples/kernel-only/lasso-cov.scm` が Gram 行列上の降下、
`tfs-lasso-cov.scm` が移動平均設計の Gram 行列を設計行列なしに作る部分)
で書かれ、C++ へ翻訳され、pip 用に包装され、CUDA にバッチで載ります —
どの段階でも同じ生成関数です。`tfs-` 接頭辞はその時系列設計に特化した
ものの印で、残りはどんな Gram 行列でも受け取ります。

```console
$ pip install scm2cpp-lasso      # C++17 コンパイラが必要。Racket は不要
```

この 1 行はいま実際に動きます。パッケージは
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/) として PyPI に
あり、入るのはこのリポジトリが Scheme から生成した C++ です。導入先に
Racket は要りません。

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
罰則の分だけゼロ側に縮んだものです。残りのインタフェースは 2 行です:

```python
grid = model.fit_path_batch(lambdas)         # すべての lambda をゼロから。GPU があれば並列
betas = model.bootstrap(lam, n_boot=500)     # 再標本をまとめて 1 バッチで当てはめ直す
```

下の数字は `bench/lasso-table.py` が RTX 4090 と i9-10900X で出すものです。
普通の密な設計行列、p=200 列、n=1800 行、4096 個の lambda の格子、すべての
lambda をゼロから — 暖かい開始が使えない交差検証格子の形です。両者とも同じ
設計行列から始めるので、Gram 行列を組む時間は翻訳カーネルの側に入っており、
BLAS は 1 スレッドに固定してあるので CPU の行は 1 コア対 1 コアです。翻訳
カーネルには tol=1e-8 を、sklearn には既定の 1e-4 を課しているので、この
比較は控えめです。厳しいほうの許容誤差まで解いた側が翻訳カーネルで、GPU と
CPU の答えは 1.3e-15 まで一致します:

| ソルバ | 時間 |
|---|---|
| sklearn `Lasso.fit` を lambda ごとに、冷たく | 26.4 秒 |
| sklearn、`precompute=True`(n > p での `'auto'` の選択)、冷たく | 30.4 秒 |
| 翻訳した cov カーネル、CPU 1 コア、冷たく | 1.0 秒 |
| 翻訳した cov カーネル、GPU、lambda 1 つにブロック 1 つ | 0.05 秒 |

(scikit-learn 1.9.0。`Lasso` の既定は `precompute=False`。`lasso_path`
と `LassoCV` の既定 `'auto'` はこの n > p では Gram 経路を選びますが、
冷間の当てはめでは毎回 Gram を作り直す分だけ払うので、ここでは
遅い方になります。)

逐次の単一パス、つまり両者とも暖かい開始が使える仕事では互角です。400 個の
lambda のパスで、sklearn の既定である 1e-4 なら 0.058 秒対 0.078 秒、両者に
1e-8 を要求すると 0.101 秒対 0.090 秒で、係数は 7e-9 まで一致します。差が
開くのは仕事が逐次でないときで、それを測ったのが上の表です。

### pip で入る他の lasso との比較

`bench/lasso-compare.py` は、この環境で `pip install` できる lasso 全部 —
scikit-learn 1.9.0、celer 0.7.4、skglm 0.5、RAPIDS cuML 26.8 — に同じ
冷たい格子を解かせます。各ソルバは自身の既定許容誤差で走り、計測前に
1 回の計測外フィット(numba のコンパイルを時計から外すため)、cuML は
計測開始前にデータをデバイスへ置いた状態です。最終列は最小 lambda に
おける各ソルバの目的関数と当方の差 — 速いが緩い答えはここに現れます:

| ソルバ | 時間 | 目的関数の差 |
|---|---|---|
| scm2cpp-lasso、CPU 1 コア (tol 1e-8) | 0.9 秒 | 0 |
| scm2cpp-lasso、GPU、lambda 1 つに 1 ブロック | 0.05 秒 | 0 |
| sklearn `Lasso.fit` を lambda ごと | 12.5 秒 | +1.6e-09 |
| sklearn、`precompute=True`(n > p での `'auto'` の選択) | 15.0 秒 | +1.6e-09 |
| celer を lambda ごと | 17.3 秒 | 0 |
| skglm を lambda ごと | 16.4 秒 | +2.8e-17 |
| cuML を lambda ごと、GPU | 57.5 秒 | +9.1e-07 |

`precompute=True` の行は、負荷のかかった機械での後の実行(全行が 1.4
倍遅く、こちら 1.3 秒 / 0.2 秒、`precompute=False` 17.8 秒、
`precompute=True` 21.3 秒、celer 23.6 秒、skglm 20.1 秒、cuML 64.9 秒)
から比で換算したもので、GPU の行は同じ負荷の機械での 3 回目の実行
(こちら 1.0 秒 / 0.046 秒、`precompute=False` 18.2 秒、`precompute=True`
20.7 秒、celer 24.1 秒、skglm 20.8 秒)のものです — 格子を lambda 1 つに
スレッド 1 本から lambda 1 つにブロック 1 つ(下の交差検証と同じ起動)に
移した後で、この格子で 4 倍速く、ビット単位で同じ答えです。`Lasso` 自身の既定は `precompute=False`
で、`'auto'`(`lasso_path` と `LassoCV` の既定)はこの n > p では
Gram 経路を選びますが、*冷間*の当てはめでは毎回 n 行から p×p の
Gram を作り直すことになるので、冷間 1 回あたりでは速くならず 1.2
倍遅く、目的関数値は同じです。`Lasso` クラスは `True`/`False` しか
受け付けないので、スクリプトはその選択を明示しています。

正直な注記を 2 つ。celer と skglm は別の領域 — 非常に大きく疎な設計
行列 — のために作られており、そこではスクリーニング規則が支配します。
p=200 の密行列ではフィットごとの準備代だけ払って本領に届きません。
cuML は 1 回のフィットの**内側**を並列化するので、1 フィットが大きい
ときに勝ちます。この規模ではフィットごとの起動オーバーヘッドが支配し、
当方の GPU 行は **lambda を跨いで**並列化します — 罰則 1 つに CUDA
スレッドのブロック 1 つ。交差検証格子が実際に差し出す並列軸はこちらです。
R の glmnet はこのアルゴリズム族の祖先ですが、現行 Python でビルド
できる移植が存在せず、族そのもので代表されています。

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
warm CPU パス)。cv=5、alpha 100 個、CPU 1 コア、sklearn 1.9.0、
3 回実行の最良値、Gram 込みの推定器全体:

| n | p | CPU | CUDA | sklearn `LassoCV` |
|---|---|---|---|---|
| 1,800 | 200 | 0.36 秒 | 0.03 秒 | 0.23 秒 |
| 5,000 | 1000 | 3.9 秒 | 0.39 秒 | 2.7 秒 |
| 100,000 | 200 | 0.75 秒 | 0.60 秒 | 3.9 秒 |
| 100,000 | 500 | 2.0 秒 | 1.8 秒 | 12.6 秒 |

(この表は他のジョブとコアを共有する機械 — 20 スレッドで負荷 14 —
で取ったもので、絶対時間はこの README の前の表より 2〜3 倍大きい。
比が要点です。)格子の起動そのものは n=1,800 で 9 ms、n=5,000,
p=1000 で 64 ms。n=100,000 の CUDA 列はほぼ全部が Gram の積で、CPU
パスも同じ積を払います。機構が効くのはいずれにせよ大きい n です:
Gram の下流は 100,000 行に二度と触れません。n=5,000, p=1000 では
sklearn の生 X 上の降下が当方の Gram 経由 CPU パスより速く、GPU が
その差を 7 倍返しにします。CPU と CUDA の選ぶ alpha は全サイズで
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
`n_jobs=None` と同じ逐次で、ベンチは双方 BLAS 1 スレッド固定。GPU が
あれば CV 格子は `CovLassoCV` と全く同様に 1 回の起動 — (fold, alpha)
セルごとにブロック 1 つ、p × T の係数ブロックは共有メモリ
(`force_cpu` で降りられます)。プロトコルは上と同じ、タスク数 8、
単発 fit は alpha = 0.1 lambda_max、CV は両者同一の 100 alpha 格子:

| 推定器 | n | p | 当方 | 当方 `n_jobs=5` | 当方 CUDA | sklearn |
|---|---|---|---|---|---|---|
| MultiTaskLasso | 100,000 | 200 | 0.15 秒 | -- | -- | 0.80 秒 |
| MultiTaskLasso | 100,000 | 500 | 0.53 秒 | -- | -- | 1.9 秒 |
| MultiTaskLassoCV | 1,800 | 200 | 1.5 秒 | 0.33 秒 | 0.08 秒 | 0.51 秒 |
| MultiTaskLassoCV | 100,000 | 200 | 1.6 秒 | 0.62 秒 | 1.7 秒 | 76 秒 |
| MultiTaskElasticNetCV | 1,800 | 200 | 1.6 秒 | 0.51 秒 | 0.10 秒 | 1.0 秒 |
| MultiTaskElasticNetCV | 100,000 | 200 | 1.6 秒 | 0.68 秒 | 1.9 秒 | 164 秒 |

(`MultiTaskElasticNet` の単発 fit は `MultiTaskLasso` と同時間。CUDA
列は上の `CovLassoCV` 表と同じ混んだ日に取ったもので、その日の逐次
CPU 行は 1.5 / 2.0 / 1.6 / 2.1 秒、sklearn は 0.56 / 114 / 0.99 /
241 秒でした。)n=1,800 の逐次 CV は sklearn より遅い — 既定 tol=1e-8
は sklearn の 1e-4 の双対ギャップ停止より多く掃引し、そのサイズでは
節約できる行がない — そして GPU 格子は全体を 0.1 秒で済ませます。
n=100,000 では Gram 経路が 48 倍・100 倍先行し、絶対時間は n=1,800
からほぼ変わりません。そこでの CUDA 列は Gram の積で、CPU パスが作る
のと同じものです。係数は厳しい tol で sklearn と 1e-15
一致、CV 対も同じ alpha を選び係数は 1e-13 一致です。

#### 速度をメモリに戻す

上の速さはどれも p × p の Gram 行列で買っています。もう一方の選択が
`examples/kernel-only/lasso-kernel.scm` です。残差形の座標降下で、X の
ほかに n ベクトルを 1 本だけ持ち、座標ごとに X の列を 2 回読む —
scikit-learn の `Lasso(precompute=False)` の中身と同じアルゴリズムで、
メモリ目的が残すのはこのプログラムです(covariance 書換えこそが
p × p ブロックを割り当てる一歩なので)。両形は同じ導出の両端で、
`--derive` が `lasso-kernel.scm` を Gram 形に変えます。カーネルは本体の
先頭で形を宣言し(`(with-arrays ((x (p n)) (resid (n)) ..) ..)`。
素の翻訳には何の影響もありません)、導出は平坦なループを配列代数へ
持ち上げ、残差が X の行のスカラー倍で更新され別の行との内積でしか
読まれないことを見て、残差を Gram 行列で保守するメモ `c = X'r` に置き
換えます。カーネルは動かなかった座標の残差更新を飛ばし、何も動かなかった
掃引で止まるので、その両方が手つかずのまま `c` の更新と導出物の掃引
ループへ持ち越されます。差分化が外へ出すループ入れ子は配列全体の積に
畳まれます(`derive: lasso: raise differencing matmul`): Gram
`(array-set! g (matmul x (transpose x)))`、メモの構築
`(array-set! c (matmul x resid))`、残差の復元
`(array-dec! resid (matmul (transpose x) (- beta b0)))` — multi-task
カーネルでは同じ 3 つの行列形。それぞれの展開はループ入れ子(Gram は
上三角とその写し)で、`--blas` はそれぞれを CBLAS 呼び出し一回 —
`dsyrk`、パッケージが BLAS に渡しているのと同じ積 — に置き換えるので、
導出物はパッケージと同速で走ります(下の表。`--blas` なしでも一致は
しますが、Gram 行列をスカラーのループ入れ子で作る O(np²) が支配します)。
`--cublas` は同じことを cuBLAS で、設計行列を一度アップロードして
行います。カーネルは罰則の列(path)を
取り、各 fit を前の fit から暖かく始めます。それも導出の目に入ります。
差分化される掃引は罰則ループ全体なので、Gram 行列はその前で一度だけ
作られ、`c` は warm start をまたいで持ち回られます — パッケージと同じ
です。`--derive` に `-S` を添えると導出後のプログラムが
`lasso-kernel.expanded.scm` に、翻訳器がそのまま受け付ける Scheme として
書き出されます。手書きの `lasso-cov.scm` と読み比べられるよう、その
ファイルはカーネルの隣に置いてあります。
`bench/lasso-memory-compare.py` は両形を scikit-learn の両形と*等しい
仕事*で比べます。列に AR(1) 相関(ρ 0.9)を入れて降下が現実的な
掃引数になるようにし、その数 S は scikit-learn 自身の収束が決め、
全行が同じ λ(0.01 λmax)でちょうど S 回まわす。CPU 1 コア、X は
双方とも自分の配置で事前に渡す。`bench/resid-cd.cu` は残差形の
座標ステップの長さ n のループ 2 本を GPU 全体に分散し、間にグリッド
バリアを置いたもの — 計測用の手書きで、翻訳出力ではありません。

| ソルバ(S = 43 / 35 / 44 / 29 掃引)          | 1,800 × 200 | 5,000 × 1000 | 100,000 × 200 | 100,000 × 500 |
|-----------------------------------------------|-------------|--------------|---------------|---------------|
| sklearn `Lasso(precompute=False)`             | 0.014 秒    | 0.38 秒      | 1.8 秒        | 2.8 秒        |
| `lasso-kernel.scm`、`-O3 -march=native`       | 0.023 秒    | 0.39 秒      | 2.2 秒        | 3.6 秒        |
| `lasso-kernel.scm`、同上 + `-ffast-math`      | 0.010 秒    | 0.26 秒      | 1.7 秒        | 2.8 秒        |
| 残差形 GPU(`resid-cd.cu`)                   | 0.034 秒    | 0.17 秒      | 0.90 秒       | 1.5 秒        |
| sklearn `Lasso(precompute=True)`              | 0.005 秒    | 0.13 秒      | 0.17 秒       | 0.60 秒       |
| `CovLasso`、Gram 構築込み                     | 0.005 秒    | 0.12 秒      | 0.15 秒       | 0.50 秒       |
| `lasso-kernel.scm --derive`、積はループ入れ子 | 0.035 秒 | 4.7 秒       | 4.5 秒        | 28 秒         |
| `lasso-kernel.scm --derive --blas`、`-lopenblas` | 0.002 秒 | 0.094 秒     | 0.16 秒       | 0.58 秒       |
| `lasso-kernel.scm --derive --cublas`、アップロード込み | 0.002 秒 | 0.032 秒 | 0.061 秒      | 0.16 秒       |
| `lasso-auto.scm --blas`、手書きの Gram 経路   | 0.002 秒    | 0.12 秒      | 0.16 秒       | 0.65 秒       |
| `lasso-auto.scm --cublas`、アップロード込み   | 0.002 秒    | 0.033 秒     | 0.066 秒      | 0.14 秒       |
| 追加メモリ、残差形 / Gram 形                  | 14 KB / 312 KB | 39 KB / 8 MB | 781 KB / 312 KB | 781 KB / 2 MB |

`--derive` の 3 行は同じスクリプトの別の回で、その回の `CovLasso` は
0.002 / 0.108 / 0.155 / 0.51 秒、`Lasso(precompute=True)` は
0.004 / 0.099 / 0.175 / 0.60 秒でした。`--blas` 付きの導出物は全形状で
手書きパッケージと scikit-learn の間に入り、最大形状では自身のループ
入れ子の 50 倍速。`--cublas` は X のアップロード込みでさらに 3〜4 倍です。
`lasso-auto.scm` の 2 行は手書きの Gram 経路(`lasso-cov.scm` の
`cov-descend` を、同じ 3 つの積を matmul 形で手書きした前処理の後ろに
置いたもの、下記)で、さらに別の回のもの。その回の `--derive --blas` /
`--cublas` は 0.002 / 0.096 / 0.18 / 0.62 秒と 0.002 / 0.029 / 0.060 /
0.14 秒でした。導出したカーネルと手書きのカーネルは同じ `dsyrk` の上の
同じ掃引ループで、時間は回ごとの揺れの範囲で一致します。導出が省くのは
3 つの積を書く手間であって、時間ではありません。

`examples/kernel-only/lasso-auto.scm` は scikit-learn の
`precompute='auto'` と同じ選択を手で書いたものです。観測数が特徴数より
多ければ(`n > p`)Gram 行列を作って `lasso-cov.scm` の `cov-descend` を
その上で走らせ、そうでなければ `lasso-kernel.scm` の `lasso` が残差を
持ち回ります。どちらも include で取り込むので、このファイルにあるのは
分岐と Gram の準備だけです。3 つの積は最初から `matmul` 形で書いてある
ので `--blas` / `--cublas` は導出物のときと同じにそれを下ろし、翻訳は
`--derive` *なし*で行います。導出をかけると残差経路まで Gram 経路に
なってしまい、`n <= p` で残差経路を残す — O(np^2) の Gram 構築を
O(p^2) の掃引で回収できない領域 — という分岐の意味がなくなるからです。
同じ AR(1) 設計で `lasso_path(precompute='auto')` と比べる(lambda_max
から 0.01 lambda_max まで 20 本の罰則、両側とも各 50 掃引、`-O3
-march=native`、1 コア)と、係数は全形状で 1.5e-10 まで一致し、時間は
次のとおりです。

| n x p (経路)              | sklearn `lasso_path` | `lasso-auto.scm` | `--blas` | `--cublas` |
|---------------------------|----------------------|------------------|----------|------------|
| 1,800 x 200 (Gram)        | 0.017 秒             | 0.038 秒         | 0.029 秒 | 0.28 秒(コンテキスト生成込み) |
| 5,000 x 1,000 (Gram)      | 0.21 秒              | 5.2 秒           | 0.17 秒  | 0.069 秒   |
| 100,000 x 500 (Gram)      | 1.4 秒               | 28 秒            | 0.49 秒  | 0.18 秒    |
| 200 x 1,800 (残差)        | 0.17 秒              | 0.36 秒          | 0.35 秒  | 0.35 秒    |
| 1,000 x 5,000 (残差)      | 6.5 秒               | 11 秒            | 11 秒    | 11 秒      |
| 2,000 x 20,000 (残差)     | 55 秒                | 83 秒            | 84 秒    | 85 秒      |

Gram 側は導出カーネルの話の繰り返しです(積がコストのすべてで、それを
BLAS かデバイスが引き受ける)。残差側には下ろす積がないので 3 列は同じ
プログラムで、下に書く理由 — 厳密な逐次内積と BLAS の `ddot` の差 — で
scikit-learn の 1.5〜2 倍かかります。`lasso-kernel.scm` と同じく
`-ffast-math` を足すと同じ 2 形状が 0.11 秒と 6.9 秒(scikit-learn は
0.13 秒と 6.4 秒)になります。`probe/auto-lasso.scm` が小さな
2 進データで両経路をテストスイートで走らせます(素の翻訳、`--blas`、
`--cublas`)。

つまりメモリ優先の形は scikit-learn と同速で走ります — 同じアルゴリズム
なので当然ですが、計測が見えるようにした条件が 2 つあります。カーネル
は動かなかった座標の残差更新を飛ばさなければならない(scikit-learn は
飛ばす。疎な解ではほとんどの座標がそう。カーネルは今それをしており、
入れる前は 1.5–2.5 倍遅かった)。そしてコンパイラに内積の加算の並べ
替えを許さなければならない(翻訳器は厳密な逐次和を書き、gcc はそれを
ベクトル化しない。scikit-learn の BLAS `ddot` はその順序を約束して
いない)。GPU は残差形を n=5,000 以上で scikit-learn の 1.6–1.9 倍に
し、n=1,800 では負けます — 座標ごとの 2 回のグリッドバリアが、囲って
いる 1,800 回の乗算より高い。座標ステップは縮約で、バリアは CPU が
決して払わない代金です。そして Gram 形は n=100,000 でどちらの 10 倍先
にいて、代金は 312 KB〜8 MB。単発 fit では当方の Gram 形と scikit-learn
の `precompute=True` は同速です(上の CV の勝ちは Gram の引き算と
warm path であって、このカーネルではありません)。全行が scikit-learn
の参照と 1e-15 で一致(Gram の 2 行は 1e-13、Gram の和の順序が違う)。

各部分の仕組みは後述します。Python 包装は「PyPI からソルバを入れる」、
境界コピーなしの `-M` インタフェースは「速い lasso を Python から呼ぶ」、
CUDA プロファイルは「GPU 上での実行」を参照してください。

## インストール

必要なもの:

- [Racket](https://racket-lang.org/) 8.x
- [Boost](https://www.boost.org/) のヘッダ
- [astyle](http://astyle.sourceforge.net/) — 生成コードの字下げはこの外部
  プログラムが行います。無い場合、出力は 1 行にまとめて出ます
- 生成コードをコンパイルする C++17 コンパイラ。回帰スイートは C++17 で
  コンパイルします (ランタイムヘッダが取り込む Boost.Math が Boost 1.82
  以降 C++14 を要求するため)。`CXXSTD=c++20 ./run-tests.sh` も通ります
- 任意: CUDA ツールキット (`-P gpu` と `-P thrust` 用)
- 任意: numpy 入りの Python 3 (`-M` の出力を使う場合)

翻訳器が乗る miniKanren は**別途用意する必要はありません**。
`vendor/rkanren` として同梱されており、下記 2 番目のコマンドで登録され
ます。中身は「同梱 rkanren について」を参照してください。

```console
$ sudo apt-get install racket astyle libboost-all-dev g++
$ git clone https://github.com/niitsuma/scm2cpp.git
$ cd scm2cpp
$ raco link --user vendor/rkanren        # 一度だけ。PLTCOLLECTS は不要
$ ./run-tests.sh                         # PASS=71 FAIL=0 と出れば成功 (CUDA なしなら 65、cblas.h もなければ 59)
```

コレクションを登録したくない場合は `raco link` の代わりに `PLTCOLLECTS`
を設定します。末尾のコロンが必要です。

```console
$ export PLTCOLLECTS=$PWD/vendor:
```

### 同梱 rkanren について

翻訳器のユーティリティモジュールのいくつかは関係型で書かれており、
Hindley-Milner 経路でも miniKanren を読み込むため、どの翻訳にも
miniKanren が必要です — ただし `raco pkg install cKanren` で入るもの
ではありません。あのパッケージのモジュールは制約コアだけを再輸出して
おり、このコードが呼ぶ層 (`nullo`、`never-pairo` など) を含みません。
`vendor/rkanren` はその cKanren — Alvis, Willcock, Carter, Byrd,
Friedman の制約枠組み。MIT 表示はディレクトリ内に保存 — の核を
recursive miniKanren のものに交換したものです: walk と出現検査は循環
安全、単一化は等再帰的で、自己参照的な束縛は拒否せず `(==> x t)` と
注釈されます (Niitsuma, Computacion y Sistemas 22(4), 2018)。核の周りの
枠組みは無改変で、原本の無改変ライブラリはツリーではなく git 履歴
(コミット 3c945f9) に保管してあります。`vendor/mk-recursive` は同じ
変更を素の miniKanren に施したもので、関係型の型推論はそちらに乗ります。

## 使い方

```console
$ racket scm2cpp-file.scm -t scm2c.typ sample.scm
$ g++ -std=c++17 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o sample sample.cpp
$ ./sample
```

`scm2cpp-file.scm` は `sample.hpp` と `sample.cpp` を書き出します。

### オプション

| オプション | 意味 |
|---|---|
| `-t FILE` | 型注釈ファイル (`scm2c.typ` 参照) |
| `-P omp` | 反復が独立と示せた最も外側のループに `#pragma omp parallel for` を出す (「ディレクティブが付く位置」参照) |
| `-P gpu` | OpenMP のターゲットオフロード指示を出す。配列は素の配列になる |
| `-P acc` | OpenACC 指示を出す |
| `-P thrust` | 認識できたループを Thrust アルゴリズムに書き換える。配列は `thrust::device_vector` になる |
| `-I NAMES` | 指定した配列に対する「原点からの箱和」ループ入れ子を、面積和テーブル (summed-area table) への問い合わせに書き換える。NAMES は空白区切りで、各要素は `NAME` か `NAME:RANK`、あるいは `auto`。階数 (走査和なら 1、画像なら 2、以下同様) は入れ子自身から発見されるので、`:RANK` は「そうであるはず」という主張であり、食い違えば書き換えを拒否します |
| `--cost OBJ` | 導出 driver が何を最適化するか: `speed`(既定)か `memory`。`memory` では確保セル数が先に判定し、時間コストは同点の決着にだけ使われます。表 1 本とループを交換する候補は時計には得でも損と判定され、見送られます |
| `--blas` | 配列全体の積(`matmul`: 導出が外へ出す Gram `g = X X'`、`c = X r`、`r -= X' d`、および一般の `a b'`、`a b`、`r -= d' x`)を CBLAS 呼び出し(`dsyrk`、`dgemv`、`dgemm`)に出す。束縛 `bindings/cblas-binding.scm` 経由 — 利用者自身の C++ が通るのと同じ custom-binding 機構なので、各演算は他の束縛と同じく宣言・モデル化・検査されます。生成ヘッダは `scm2cpp-blas.hpp` を include し、リンクには `-lopenblas`(または手元の CBLAS)。指定しなければ各積は今までどおりのループ入れ子なので、頼まない限り BLAS に依存しません。式である被演算子は先に実体化され、束縛が宣言しない形の積は展開に任せます |
| `--cublas` | 同じ積を `bindings/cublas-binding.scm` 経由で cuBLAS 呼び出しに出す。関数が読むだけの行列は `with-arrays` スコープの先頭で一度アップロードされ(`dmat-upload`)、書く行列は呼び出しごとにコピー、各演算はデバイスで走って結果を戻します。ヘッダは `scm2cpp-cublas.hpp` を include。CUDA の include パスを付けて `-lcublas -lcudart` をリンク(ホストコンパイラで足ります。カーネルは何もありません)。積が支配的なときだけ得 — コピーが代金です |
| `--derive` | 関数が宣言した配列の形(本体先頭の `with-arrays`: 階数 2 は行列、階数 1 はベクトル)から座標降下の covariance 形を導出する。残差の掃引を配列代数へ持ち上げ、作業ベクトルの更新を差分化して、外へ出した Gram 行列で保守するメモに置き換え、呼び出し元が残差を読むなら最後に復元します(生存解析が決める)。宣言のない関数には触れず、宣言のないプログラムはバイト単位で同じ翻訳になります。標準エラーの `derive: NAME: raise differencing` が発火を報告し、`-S` で導出後のプログラムを Scheme として保存できます |
| `--binding FILE` | 宣言された演算を FILE に従いユーザ提供の C++ ヘッダへ対応づける。`examples/custom-template/` を参照 |
| `-M` | 実行ファイル用のソースに加えて `NAME_capi.cpp` (extern "C" ラッパ) と `NAME.py` (ctypes ローダ) を出し、翻訳された関数を Python から numpy 配列に対して呼べるようにする |
| `--llm-hints CMD` | ソースを標準入力として CMD を実行し、その標準出力を `-I` 用の空白区切り配列名として使う。指定しない限り無効。CMD は Scm2Cpp の一部ではなく、通常はローカルに立てたモデルへのラッパです |

環境変数:

| 変数 | 意味 |
|---|---|
| `SCM2CPP_RELATIONAL=1` | 関係型の型推論 (`--inference relational` と同義): recursive miniKanren の型付け関係で、旧関係型導出が後退先 |
| `SCM2CPP_INTEG` | `-I` と同じ |
| `SCM2CPP_LLM_HINTS` | `--llm-hints` と同じ |
| `PLTCOLLECTS` | rkanren の在り処 |

### ディレクティブが付く位置

`-P omp`、`-P gpu`、`-P acc` は単に最外ループに注釈を付けるわけではありません。
候補は外側から順にループ運搬依存の有無を検査され、最初に通ったループに
ディレクティブが付きます。どれも通らなければその関数は逐次のままです。
検査は片側に保守的で、そのループのどの反復も触らない場所へ書き込むことが
証明できた場合にのみ注釈を付けます。したがって並列化できたはずのループが
そのまま残ることはありますが、できないループに注釈が付くことはありません。

何をもって証明とするか:

- すべての `vector-set!` の添字がループ変数について単射であること。添字が
  変数そのものであるか、行優先の `(+ (* i S) rest)` の形で `rest` が `i` を
  含まず `S` が内側ループの回数であること (これが行同士を素にします)
- ループが書き込む配列が、別の添字で読まれていないこと (それは他の反復の
  要素だからです)
- ループ内で代入されるスカラーが、ループ内で束縛されていて私的であるか、
  あるいは `(set! acc (+ acc E))` の形でのみ更新されること。後者では
  ループを拒否する代わりにディレクティブが `reduction(+:acc)` を伴います

たとえば座標降下では、掃引ループは前の掃引が書いたものを読むので拒否され、
座標ループは `c` 全体を書いてその 1 要素を読むので拒否され、ディレクティブは
最内の更新に付きます。`cs[i]` を読んで `cs[i+1]` を書く prefix sum は
どの階層でも拒否され、逐次のままです。

スレッドは無料ではないので、注釈が付いたループには番人も付きます:
`#pragma omp parallel for if(p > 1024)`。反復回数がリテラルで閾値未満の
ループには、そもそも注釈を付けません。閾値は `SCM2CPP_OMP_MIN` (既定 1024)
です。実行時に決める意味は、1 つの翻訳済みカーネルが 100 列でも 10 万列でも
呼ばれうるところにあります。

`./run-tests-omp.sh` は、`run-tests.sh` が逐次出力を検査するのと同じやり方で
これを検査します。`-P omp` で翻訳し、`-fopenmp` でコンパイルし、Racket と
結果を比べます。競合は毎回顕在化するとは限らないので、1 事例につき複数回
走らせます。

### 積分画像の書き換えと `--llm-hints`

`-I` は、各軸について配列自身の広がりまでのすべての添字 `i1,...,ik` に対し、
原点 `(0,...,0)` からその添字までの箱にわたる和を計算するループ入れ子 —
階数 `k` に対して O(n^(2k)) の計算 — を、1 回 O(n^k) の面積和テーブル構築と
O(n^k) 回の問い合わせに書き換えます。階数は与えるものではなく、入れ子が実際に
持つ軸数から発見されるので、同じオプションが素の列に対する走査和 (`k=1`)、
2 次元画像 (`k=2`)、3 次元体積、と正方でも長方形でも同じように働きます。
書き換えはその形が正確に認識されたときだけ発火するので、違う配列を挙げても、
入れ子が合致しない配列を挙げても、コードは変わりません。実際に見つかった
階数と食い違う階数を指定した場合 (3 軸の入れ子に `v:2`) も同様です。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -I v sample.scm       # 手で示唆
$ racket scm2cpp-file.scm -t scm2c.typ -I "v w" sample.scm   # 複数
$ racket scm2cpp-file.scm -t scm2c.typ -I v:2 sample.scm     # 階数を主張
$ racket scm2cpp-file.scm -t scm2c.typ -I auto sample.scm    # 全配列を試す
```

`--llm-hints` は `-I` の引数を手で与える代わりに提案させます。CMD は
プログラムのソースを標準入力として実行され、原点からの箱和でしか読まれないと
判断した配列の名前を空白区切り (必要なら `NAME:RANK`) で標準出力に印字すること、
あるいは何も出さないことが期待されます。CMD はその約束を守る任意のコマンドで、
Scm2Cpp は同梱しません。OpenAI 互換エンドポイントへの 1 行ラッパで十分です。

```python
#!/usr/bin/env python3
# llm-hint-cmd -- 標準入力からソースを読み、配列名を標準出力に印字する
import sys
from openai import OpenAI

client = OpenAI(base_url="http://localhost:4000/v1", api_key="...")
resp = client.chat.completions.create(
    model="qwen3.6",
    messages=[
        {"role": "system", "content":
         "Some arrays are written first and afterwards only read inside a "
         "loop nest that sums, for every index up to the array's own extent "
         "on each axis, every element from the origin to that index -- a "
         "box sum from the origin, of whatever rank the array has. Reply "
         "with ONLY the space-separated names of those arrays, or nothing."},
        {"role": "user", "content": sys.stdin.read()},
    ],
    max_tokens=100,
)
print(resp.choices[0].message.content)
```

```console
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints ./llm-hint-cmd sample.scm
$ racket scm2cpp-file.scm -t scm2c.typ --llm-hints "ask-local -n 100" sample.scm
```

1 つの列の複数の文が同じ配列に対する箱和の入れ子であり、その間の区間が
その配列について書き込み無しだと解析が示せるとき (`set!` なし、
`vector-set!` なし、ある関数が書き込む引数を通じてそこに届く呼び出しもなし)、
最初の入れ子で 1 つのテーブルを作り、残りが共有します。間に書き込みがあれば
入れ子は単に分かれ、それぞれが自分のテーブルを持ちます。同じ関数単位の書き込み
解析は、関数が決して書かないコンテナ引数を、生成される署名で `const ... &` と
印づけるのにも使われます。

CMD が見つからない場合や、使える出力を出さなかった場合、翻訳は
`--llm-hints` が与えられなかったかのように進みます。いずれにせよ提案は
あくまで示唆です。名指しされた配列も、箱和の形が実際に認識されたときだけ
書き換えられるので、誤った提案は何も変えません。そして結果は他のビルドと
同様に検査されることが前提です — `./run-tests.sh` は、どのオプションで
生成されたかに関わらず、すべての回帰事例を翻訳し、コンパイルし、実行します。

### 何を保存するかの提案: `repeat-scan.rkt` と `memo-propose.rkt`

`repeat-scan.rkt` は、厳密にできる部分を担います。副作用のない部分式は
その自由変数の関数なので、それらの変数が一致すれば 2 つの出現も一致します
(ループ添字も含めて)。このツールは、繰り返される副作用のない部分式を、
何に依存しているかとともに列挙し、反復ごとに変わる変数とそうでない変数を
分けて示し、`-c CMD` を与えるとどれをテーブルにする価値があるかをモデルに
尋ねます。繰り返しを見つけるのは機械的な作業ですが、どれを保存すべきかは
ループの入れ子構造とテーブルの大きさに依存し、そここそ尋ねる価値のある
判断です。移動平均に対する lasso について尋ねたところ、ローカルモデルは
すべての候補を却下し、30x600 のテーブルは埋めるほうが省く算術より高くつくと
理由づけました — 実測が既に裏づけていた通りです。限界はその作業階層に
あります。素朴な二次の prefix sum には繰り返される部分式が 1 つもありません。
そこでの無駄は繰り返された式ではなく重なった範囲だからです。

`memo-propose.rkt` は別の問いを立てます。「この形を書き換えよ」ではなく
「繰り返しの作業を共有するには何を保存すべきか」です。会話を段階に分けて
進め (何を保持するか、次にプログラム自身の構造がそれを保持可能にするか、
最後に書き換え後のプログラム)、答えを 2 つの関門にかけます。1 つ目は
お馴染みのもの、元と同じものを印字すること。2 つ目は複数のサイズで時間を
計り、コストの伸びが明らかに緩やかであることを要求します。ここでの提案は
完全に正しくてまったく速くならないことがあり、それを見分けられるのは
計時の関門だけだからです。

```console
$ racket memo-propose.rkt -c "ask-local -n 900" -s "400=400,1600,3200" \
    -o faster.scm kernel.scm
  original: (1.0 5.6 38.5)  (grew 37.4-fold)
  proposed: (0.4 0.4 0.5)   (grew 1.2-fold)
memo-propose: accepted -> faster.scm
```

`-s NAME=A,B,C` は、変化させるプログラム中のリテラルを指定します。2 つ目の
関門は働きに見合います。すべての部分和を律儀にテーブルへ保存しておきながら
結局再計算する書き換えは、答えの検査は通り、ここで「コストの伸びが元と同じ
ままだ」と告げられて拒否されます。

### 生成コードのコンパイル

| 設定 | コンパイラ起動 |
|---|---|
| 既定 | `g++ -std=c++17 -include boost/operators.hpp -include boost/optional.hpp` |
| `-P omp` | `-fopenmp` を追加 |
| `-P gpu` | `-fopenmp -foffload=nvptx-none -fcf-protection=none -fno-stack-protector` を追加 |
| `-P thrust` | `nvcc -O2` でコンパイル |

## 対応している部分集合

`define`、`lambda`、`let`、名前付き `let`、`letrec`、`if`、`cond`、`when`、
`unless`、`begin`、`do`、`set!`、`define-macro`、`define-syntax`、
`vector-ref`、`vector-set!`、`vector-length`、`make-vector`、`list`、
`make-list`、`list-ref`、`car`、`cdr`、`cons`、`display`、`newline`、
`string-append`、`not`、`zero?`、数値演算子と比較、通常の初等超越関数、
`delay`/`force` と遅延ストリーム、`make-hash`、`hash-ref`、`hash-set!`、
`hash-has-key?`、`hash-count`。

非対応: 継続、一般の末尾呼び出し除去、提供されるリスト型・ストリーム型を
超える任意のヒープ確保再帰データ、および上記以外の R7RS。

promise はメモ化する呼び出し可能オブジェクトで、promise のベクタは遅延表に
なります。`(make-vector n (delay 0))` に、他のセルを force する `(delay ..)`
を詰めれば、依存順に埋まる動的計画法で、各本体は 1 回だけ走ります
(`probe/promise-table.scm`)。force は const 解析で書き込みとして扱われ
(`const` 参照越しに force した promise は毎回計算し直す)、promise の表は
可変参照で捕獲されます。

ハッシュ表は鍵型と値型を 1 つずつ持ち、どちらも使われ方から推論されます。
`(make-hash)` は `std::unordered_map<K,V>` に、鍵自体がコンテナなら
`std::map<K,V>` になります。既定値付き `hash-ref` は `count ? at : 既定値`、
`hash-has-key?` は `count > 0`、`hash-count` は `size` です。表はベクタと
同じく関数呼び出しを参照で越え、`hash-set!` は書き込みとして数えられます。
これが、引数が小さな整数添字でない関数のメモ化です。表は実際に呼ばれた
分だけ育ちます(`probe/hash-memo.scm` は疎な引数にわたる Collatz の
ステップ数をメモ化し、文字列鍵の集計も行います)。`define-memo` マクロは
普通の `define-macro` ソース `probe/define-memo.scm` で、include で取り
込みます。メモ化する本体の文は文の位置に置く必要があります。`let` に
束縛された `(begin ..)` は C++ の式にならなければならないからです。
`probe/fib.scm` は誰もが知る 1 つの関数の上に 2 つのイディオムを並べた
ものです — ハッシュ表による `fib-memo` と promise のベクタによる
`fib-lazy` で、fib(40) に対しどちらも本体が 41 回走ることを Racket と
C++ の両方で示します。どちらも書き換えが見つけるものではありません。
木構造の再帰を表埋めループにしていた規則は規則探索とともに消え、代わり
にサブセットが用意するのがこの 2 つの形です。

トップレベルの `(include "file.scm")` は Racket の `include` と同じく、
そのファイルのフォーム群の代わりです。パスは書かれたファイルからの相対で、
含まれたファイルがさらに include してもかまいません。差し込みはテキスト
上で、何かがプログラムを読む前に行われるので、翻訳器・オラクル・提案
ツール・`-S` はどれも 1 つのプログラムを見ます。`-M` の Python ローダと
生成される C++ に違いは現れません。`examples/` の lasso カーネル群は
`soft-threshold` をコピーではなくこの形で共有しています
(`examples/kernel-only/soft-threshold.scm`)。1 つのファイルは 1 つの
プログラムに 1 度だけ差し込まれます。直接でも別の include 経由でも、
2 度目の include は何も足しません。そのため `soft-threshold.scm` を
それぞれ include する 2 つのカーネルを並べて include できます
(`examples/kernel-only/lasso-auto.scm` が `lasso-kernel.scm` と
`lasso-cov.scm` を取り込みます)。

Scheme の値は定まった型の C++ オブジェクトへ対応づけられます。その帰結を
1 つ明記しておきます。名前をベクタに束縛すると別名になります — 2 つの名前は
1 つのベクタを指し、翻訳器はどちらを通じた書き込みも両方から見えるように
参照を出します。この対応が破れるのは、そうした名前を `set!` で指し直すときです。
C++ の参照は指し直せないので、翻訳器はコピーに退避し、警告します。
`(set! v w)` の後、両言語は食い違います。Scheme は `v` を通じて `w` の
ベクタへ書きますが、C++ はコピーへ書きます。名前を指し直すのではなく、
要素を通じて代入するか、意図したベクタを渡してください。

### 配列と fold の層

すべての翻訳単位には組み込みの `define-macro` 群が種として与えられます
— 正典は `array-macros.scm` で、同名マクロを定義するファイルは組み込みを
上書きできます。格納は配列 1 つにつきフラットなベクタ 1 本、添字は常に
1 つのアフィン式なので、生成される C++ は手書きのフラットカーネルと同じ
ループネストになり、更新形式は導出(`--derive`)が持ち上げるちょうどの形に
展開されます — この層で書いた掃引が導出から代数を隠すことはありません。

| 形式 | 意味 |
|---|---|
| `(range-for (i n) body ...)` / `(range-for (i a b) body ...)` | ループ `i = 0..n-1` / `a..b-1` |
| `(range-fold ((acc init) (i n)) e)` | fold。`e` が次の `acc` を与える |
| `(range-sum (i n) e)` | `e` の総和(名前なしの fold) |
| `(with-arrays ((a (d0 d1 ...)) ...) body ...)` | 形状つきフラット配列の宣言 |
| `(array-ref a i j)` / `(array-set! a i j v)` | 行優先の添字。値は最後(SRFI 25 と同じ) |
| `(array-inc! a i j e)` / `(array-dec! a i j e)` | `a[i,j] += e` / `-= e` |
| `(array-inc! y e)` / `(array-dec! y e)` | ベクタ式 `e` の要素ごと `y += e` / `-= e` |
| `(array-sum e)` | ベクタ式の総和 |
| `(array-reduce op id e)` | `+` `*` `min` `max` と単位元 `id` による同じ fold |
| `(array-set! s i j (array-sum (box v i j)))` | 前置 box 和: `s[i,j]` に `[0,i]×[0,j]` 上の fold |
| `(array-sum (sub a lo1 hi1 ...))` | 超矩形上の和 — numpy の `a[lo1:hi1, ...].sum()` |
| `(array-dot u v)` | `(array-sum (* u v))` |
| `(array-gather! dst src idx)` | `dst[i] = src[idx[i]]` — numpy の `dst = src[idx]`。反復が独立なので `-P omp` で並列化 |
| `(array-permute! a idx)` | 一時コピー経由の `a = a[idx]` |
| `(row-inc! a i e)` / `(row-dec! a i e)` | 2 次元 `a` の行 `i` に `+= e` / `-= e` |
| `(array-set! y e)` | ベクタ式 `e` の `y = e`。2 次元 `y` と行列式 `e` なら行列全体(`array-inc!`/`array-dec!` も同様) |
| `(array-set! g (matmul x (transpose x)))` | 2 次元 `x` の行どうしの Gram `g = x x'`、numpy の `x @ x.T`。展開は上三角とその写し。一般の積は `(matmul a (transpose b))` と `(matmul a b)` |
| `(array-set! c (matmul x v))` | ベクタ `v` に対する `c = x v` — 各行の内積 |
| `(array-dec! r (matmul (transpose x) d))` | ベクタ `d` に対する `r -= x' d`、スカラ倍した行の和(`array-inc!`/`array-set!` も同様)。`d` が行列式なら行ごとの `r -= d' x` |

**ベクタ式**とは: 宣言済みの 1 次元名、`(row a j)`(展開時の
array-curry)、`(slice u lo hi)` / `(slice u lo hi step)`(numpy の
`u[lo:hi:step]`、半開区間)、スカラをブロードキャストするベクタ式上の
`(+ - *)`、そして `(scale c v)`(名前を持ったスカラ倍)。**行列式**は
宣言済みの 2 次元名と、その上の `(+ - *)` / `(scale c m)`。式の木は展開まで
見えたままなので、導出は代数に対して働けます: `y -= coef*u` は
`(array-dec! y (scale coef u))` であり、構造を隠す融合プリミティブでは
ありません。`matmul` の各形は導出が外へ出す積をそのまま書いたもので、
`--blas` / `--cublas` はそれぞれをライブラリ呼び出し一回に置き換えます
(意味はループ入れ子、呼び出しは同じ積をライブラリから)。

### 部分集合が期待する作法

- union 型なし: 「ベクタまたは `#f`」は翻訳できない。事前確保バッファ +
  0/1 フラグを使う。
- 異種 pair の返却なし: 結果としての `(cons vec num)` は翻訳できない。
  出力引数 + スカラ返却を使う。
- ループは `do` か名前付き `let`。ループの非再帰末尾は慣例として `#f`。
- 素の配列はフラット + 明示的な添字算術(`(+ (* i n) j)`)— または上の
  配列層(同じものに展開される)。
- 他に制約がないとき引数を浮動小数に強制するイディオムは `n` でなく
  `(* 1.0 n)` を掛けること。
- 生成される識別子は C++ 予約語からエスケープされない: 変数名は `new`
  でなく `bnew` に。

## テスト

```console
$ raco link --user vendor/rkanren    # まだなら一度だけ
$ ./run-tests.sh                     # PASS=71 FAIL=0 と報告 (cuBLAS や cblas.h がなければ少なくなる)。失敗があれば非ゼロ終了
$ TIMEOUT=600 ./run-tests.sh /tmp/result.txt      # 制限時間を延ばし、ログ先を指定
```

31 本のプログラムはそれぞれ翻訳され、コンパイルされ、実行され、そして
**その出力が、同じプログラムを Racket で走らせた結果と比較されます**。
4 段階すべてが成功しなければなりません。最初の 3 つは処理系がまだ動くことを
示すだけで、翻訳が今も Scheme の意味を保っていることを示すのは比較です。

仕様は Scheme そのものなので、古びていく期待出力ファイルはありません。
`test-oracle.rkt` が両側を供給し、単体でも使えます。

```console
$ racket test-oracle.rkt run bench/sqrttest.scm        # Racket が印字するもの
$ racket test-oracle.rkt diff racket.out cpp.out       # 2 つの出力を比較
```

このオラクルはプログラムを `#lang racket/base` としてではなく、翻訳器の
前処理と同じように読みます。`define-macro` は展開され、片腕の `(if c t)` は
合法で、`force` は裸のサンクを受け取り、`make-promise` はサンクを取って
`scm2cpp.hpp` と同じように記憶化します。数値は相対許容誤差
(`SCM2CPP_TOL`、既定 `1e-5`) で比較されます。C++ は有効数字 6 桁で印字し、
Racket はすべて印字するからです — `2.0` と `2`、`3.00009155413138` と
`3.00009` は一致とみなし、それ以外は厳密に一致しなければなりません。
大きなトークンに埋め込まれた数 (`beta_hat=0.000436075`) は数として比較され、
周囲の文字は文字通り照合されます。

同じスイートは GitHub Actions (`.github/workflows/tests.yml`) 上で、
上記のインストール手順を経て、push と pull request のたびに走ります。
手順が壊れれば、読者の最初の 10 分ではなくそちらで露見します。

`main` が何も印字しない事例は `FAIL(no output)` として失敗します。比較する
ものが無くなり、何とでも一致してしまう事例こそ、この段階が塞ぐべき穴だからです。

新しい事例を書くときに知っておく価値のある帰結が 2 つあります。Scheme の
整数は無限精度で C++ の `int` はそうではないので、32 ビットを溢れる算術は
両辺を食い違わせます — これは設計通りで、スイートは黙って通す代わりに
そう告げるようになりました (試料生成器が小さな乗数を使うのはこのためです)。
また、実行時間が長いベンチマークループに支配されるプログラムは、オラクルが
プログラム全体を実行するため、インタプリタ上では遅くなります。

### ユーザの C++ テンプレートの結合 (`--binding`)

結合ファイルは、ユーザ自身のヘッダが Scheme からどう見えるかを宣言します。
推論のための型構成子、コード生成器のための演算 1 つにつき 1 項目、各演算の
純 Scheme モデル、そしてテストです。これにより `(mat-ref m r j)` は
`m.at(r,j)` に翻訳され、`m` は `foo::Matrix< double >` と型付けされ、
ヘッダは include に加わります。Scheme プログラムが C++ に言及することは
ありません。結合の読み込みは何も実行しません — 宣言はデータであり、モデルが
走るのは検査の関門の中だけです。

```console
$ racket binding-check.rkt -I examples/custom-template \
    examples/custom-template/foo-binding.scm
```

これはすべての `binding-test` を 2 回走らせます。一度は Racket でモデルに
対して、もう一度は実際のヘッダに対して翻訳・コンパイル・実行し、出力を
比べます。モデルがヘッダについて主張することは、こうして両方を走らせる
ことで検査されます — 導出に課すのと同じ基準です。モデルが行優先だと
言うのにヘッダが列優先で格納していれば、印字された食い違いとして捕まります。
`examples/custom-template/` に完全な作業例があります。

### 翻訳された関数を Python から呼ぶ (`-M`)

`-M` は通常の 2 つに加えてさらに 2 つの成果物を出します。翻訳された非
テンプレート関数すべてに対する `extern "C"` ラッパ `NAME_capi.cpp` (スカラーは
そのまま通り、配列参照は要素ポインタになります) と、各 numpy 配列の dtype と
サイズを宣言された署名と照合してから渡す ctypes ローダ `NAME.py` です。
関数が書き換える配列はその場で書き換えられるので、ソルバが書いた係数は
呼び出し側の配列に入ります。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M kernel.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libkernel.so kernel_capi.cpp
$ python3 -c 'import kernel; kernel.lasso(x, beta, resid, xnorm, 0.02, 20000, 360, 40)'
```

どの呼び出し側も広がりを確定しない引数は `std::vector<double>` として出て、
ポインタと長さの組で渡ります。呼び出し側が `make-vector` で作る引数は
`std::array<double,N>` のままで、ポインタだけで渡ります。したがって外から
呼ばれるために書かれた、自分の `main` を持たないカーネルは、注釈なしで
公開できます — `examples/kernel-only/` を参照してください。署名が C ABI を
渡れない関数 (共用体、クロージャ、リスト) は、黙ってではなくコメントで
名指しした上で飛ばされます。作業例では、この方法で呼んだカーネルが
scikit-learn の Lasso と 5e-11 まで一致しました。

## PyPI からソルバを入れる

ソルバには専用のパッケージがあるので、Python の利用者は Racket も
このリポジトリも必要としません。

```console
$ pip install scm2cpp-lasso     # Gram 行列に対する lasso、設計行列は任意
$ pip install scm2cpp-tfs       # 移動平均による特徴選択
```

両方とも公開済みです —
[scm2cpp-lasso](https://pypi.org/project/scm2cpp-lasso/) と
[scm2cpp-tfs](https://pypi.org/project/scm2cpp-tfs/)。このファイルの
冒頭の例は公開版に対してそのまま動きます。

```python
from scm2cpp_lasso import CovLasso
model = CovLasso(X, y)
path = model.fit_path(model.lambda_grid())

from scm2cpp_tfs import TemporalLasso
model = TemporalLasso(series, wmax=200, nobs=1800)
path = model.fit_path(y, model.lambda_grid(y))
yhat = model.predict(path[-1])           # 設計行列は最後まで作らない
```

各パッケージがコンパイルする C++ は `python/` 以下にコミットされており、
`examples/kernel-only/` からそのパッケージの `regenerate.sh` が生成します。
つまりインストールに必要なのは C++17 コンパイラだけで、翻訳器が要るのは
再生成のときだけです。インストール時に `nvcc` があれば、CUDA スレッドの
ブロック 1 つがバッチの問題 1 つ(lambda、リサンプル、CV 格子のセル)を
担当するバッチ GPU 経路も併せてビルドされます。無ければ
パッケージは同じように入って同じように動き、そのメソッドだけが欠けます。
こうしたパッケージは `python/` に 1 ディレクトリずつ置かれ、違いは
`python/README.md` (日本語版は `python/README.ja.md`) が説明します。

## 速い lasso を Python から呼ぶ

`-M` はライブラリの隣に `extern "C"` ラッパと ctypes ローダを出すので、
翻訳されたカーネルはそのまま import できます。

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/tfs-lasso-cov.scm
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libtfs-lasso-cov.so tfs-lasso-cov_capi.cpp
```

boost の include は不要です。数値カーネルには最小ランタイムが与えられます。
配列引数は呼び出し側の numpy バッファへのポインタとして渡されます — 引数は
`scm2cpp::span` ビューです — ので、カーネルはその場で読み書きし、境界で
何もコピーされません。

`examples/kernel-only/tfs-fast-lasso.py` は生成された関数のうち 4 つを小さな
クラスにまとめます。設計行列は作られません。`build_S` が元系列をラグ和に変え、
`build_P` が目的変数との相互積に変え、`build_G` が Gram 行列を組み立て、
以降 `cov_descend` は座標あたり O(n) ではなく O(p) で済みます。降下は
止まった場所から正確に再開できるので、正則化パス全体を暖かいまま歩けます。
各 lambda は前の解から始まります。

```python
model = TemporalLasso(series, wmax=200, nobs=1800)   # Gram は一度だけ
path = model.fit_path(y, lambdas)                    # lambda 1 つにつき 1 行
```

```console
$ python3 examples/kernel-only/tfs-fast-lasso.py
strongest windows at the end of the path: [1, 2, 4, 5, 20]  (the target was built from 5 and 20)
scm2cpp path of 400 lambdas: 0.107s
sklearn lasso_path (same grid, warm):  0.095s
objective gap vs sklearn: max +1.67e-16 (negative means ours is lower)
```

暖かい者同士なら両者は互角で、解は丸めの範囲で一致します。差が開くのは
仕事が逐次でないところ — 各分割が冷たく始まる交差検証の格子 — であり、
それが次節の GPU が測るものです。

## GPU 上での実行と、sklearn との比較

生成コードの本文が数値部分集合の内側に収まっていれば、最小ランタイム
(`SCM2CPP_MINIMAL`) が与えられます。boost ヘッダなし、C++17、そして
デバイスで安全な関数には nvcc の下で `__host__ __device__` が付きます。
配列引数は `scm2cpp::span` ビュー — ポインタ 1 本で、ホストでは
`std::vector` や `std::array` から、カーネルでは生のデバイスポインタから
暗黙に作られます — なので、同じ翻訳済み関数が g++ でも nvcc でもそのまま
コンパイルできます。

`cuda/batch-lasso.cu` は、翻訳された covariance-update lasso
(`examples/kernel-only/tfs-lasso-cov.scm`) をバッチ正則化パスとして走らせます。
CUDA スレッド 1 本が lambda 1 つを担い、座標降下は各問題の内部では逐次で、
各スレッドは自分の係数の最大移動量が許容誤差を下回るまで塊ごとに掃引します。
`cuda/compare-sklearn.py` は同じ問題を numpy で組み直し、同じ格子で
scikit-learn を計時します。壁時計だけを信じるのではなく、目的関数の値で
解を照合します。

数値はこの README 冒頭の例にあります。冷たい者同士では翻訳カーネルが
1 コアで sklearn の約 22 倍、GPU バッチはさらに約 10 倍で、目的関数は
同等です。sklearn の冷たい行は 256 回の当てはめからの推定です。
nvcc とデバイスがある環境で `run-tests.sh` が走らせる検査は、同じ
プログラムの小さな事例です。

## 推論を Typed Racket に対して検証する

Hindley-Milner のパスとコード生成器は 1 つの実装であり、そこにバグがあれば
独立した証人のないまま誤った C++ が出ます。`verify-tr.rkt` は推論された型を
Typed Racket の注釈に変え、プログラムを `typed/racket` モジュールとして
書き出し、2 つ目の無関係な型検査器に読ませます。

```console
$ racket verify-tr.rkt prog.scm
OK: Typed Racket agrees (Real level)
```

検査は意図的に数値の塔の Real の水準で走ります。Typed Racket は
`(* 2.5 i)` を `Flonum` ではなく `Real` と型付けし、それは正しいのです。
Racket の厳密なゼロは浮動小数点との乗算を生き延びるので、Flonum の水準は
本当にこのプログラムの Racket 意味論を記述していません。検証されるのは
構造です — 何が関数で何を取るか、何がベクタで何のベクタか、どこで値が
捨てられるか — であり、int か double かの判断は推論パスに残ります。C++ が
それを必要とするからです。束縛の対を適用と読み違える、引数リストの長さが
違う、ベクタのはずの場所にスカラーがある。Typed Racket はこれらをすべて
即座に拒否します。それはかつてすり抜けた前段バグの種類そのものです。

回帰スイートの 31 本のうち 30 本が検査を通ります。通らない 1 本は遅延
ストリームを使っており、ここでは基礎となる Typed Racket 表現を持たないため
対象外と宣言しています (`--keep` で生成モジュールをソースの隣に残せます)。

## ランタイムヘッダ

`scm2cpp.hpp` は翻訳器なしで単体でも使えます。通常の C++ コンテナに対する
Lisp 演算子を与えるので、`car`、`cdr`、`cons`、`list-ref` が

    std::vector    std::list    std::array    boost::fusion::list

に適用でき、`std::pair` はコンスセルとして扱われます。`eq?`、`eqv?`、
`equal?`、`quote` と記号演算も提供されます。`eq?` はアドレス比較です。

```cpp
template<typename T>
bool is_eq(T & x, T & y) { return (&x)==(&y); }
```

一様な列に対する `cons` と `cdr` は `std::list` のコピーを返します。それが
Scheme の意図する持続的な意味論だからです。以前の版は呼び出し側の記憶を
共有する `boost::ptr_container` のビューを返していましたが、その依存は
なくなりました。

数値プログラムにはさらに小さなヘッダが与えられます。生成された本文が数値
部分集合の内側に収まっているとき — クロージャなし、リストなし、プロミス
なし — 翻訳器は `SCM2CPP_MINIMAL` を定義し、ヘッダは std だけになり、
boost の include を 1 つも伴わずにコンパイルできます。これが nvcc に
通せる理由です。

作業例は `usage.cpp`、`list-test.cpp`、`equal-test.cpp` を参照してください。

## 文書

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

# lasso の詳細

*[English](lasso.md)* · [README](../README.ja.md)

README の最初の例で紹介した lasso ソルバの詳細です。カーネル、pip で入る他の lasso との比較、交差検証、GPU バッチ、メモリ、Python からの呼び方を扱います。

## 例: 速い lasso — Scheme から pip、そして GPU へ

最初の例として詳しく取り上げるのは lasso ソルバです。素の Scheme
(`examples/kernel-only/lasso-cov.scm` が Gram 行列上の降下、
`tfs-lasso-cov.scm` が移動平均設計の Gram 行列を設計行列なしに作る部分)
で書かれ、C++ へ翻訳され、pip 用に包装され、CUDA にバッチで載ります —
どの段階でも同じ生成関数です。`tfs-` 接頭辞はその時系列設計に特化した
ものの印で、残りはどんな Gram 行列でも受け取ります。

```console
$ pip install scm2cpp-learn      # C++17 コンパイラが必要。Racket は不要
```

この 1 行はいま実際に動きます。パッケージは
[scm2cpp-learn](https://pypi.org/project/scm2cpp-learn/) として PyPI に
あり、入るのはこのリポジトリが Scheme から生成した C++ です。導入先に
Racket は要りません。

100 本の候補列のうち信号を担うのは 3 本。どれなのかをソルバに尋ねると、
その 3 本だけを答えます:

```python
import numpy as np
from scm2cpp_learn import CovLasso

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
| sklearn `Lasso.fit` を lambda ごとに、冷たく | 15.2 秒 |
| sklearn、`precompute=True`(n > p での `'auto'` の選択)、冷たく | 18.0 秒 |
| 翻訳した cov カーネル、CPU 1 コア、冷たく | 0.95 秒 |
| 翻訳した cov カーネル、GPU、lambda 1 つにブロック 1 つ | 0.045 秒 |

(scikit-learn 1.9.1、他に何も走っていない機械。`Lasso` の既定は `precompute=False`。`lasso_path`
と `LassoCV` の既定 `'auto'` はこの n > p では Gram 経路を選びますが、
冷間の当てはめでは毎回 Gram を作り直す分だけ払うので、ここでは
遅い方になります。)

逐次の単一パス、つまり両者とも暖かい開始が使える仕事では互角です。400 個の
lambda のパスで、sklearn の既定である 1e-4 なら 0.057 秒対 0.053 秒、両者に
1e-8 を要求すると 0.071 秒対 0.057 秒で、係数は 7e-9 まで一致します。差が
開くのは仕事が逐次でないときで、それを測ったのが上の表です。

### pip で入る他の lasso との比較

`bench/lasso-compare.py` は、この環境で `pip install` できる lasso 全部 —
scikit-learn 1.9.1、celer 0.7.4、skglm 0.5、RAPIDS cuML 26.8 — に同じ
冷たい格子を解かせます。各ソルバは自身の既定許容誤差で走り、計測前に
1 回の計測外フィット(numba のコンパイルを時計から外すため)、cuML は
計測開始前にデータをデバイスへ置いた状態です。最終列は最小 lambda に
おける各ソルバの目的関数と当方の差 — 速いが緩い答えはここに現れます:

| ソルバ | 時間 | 目的関数の差 |
|---|---|---|
| scm2cpp-learn、CPU 1 コア (tol 1e-8) | 0.91 秒 | 0 |
| scm2cpp-learn、GPU、lambda 1 つに 1 ブロック | 0.044 秒 | 0 |
| sklearn `Lasso.fit` を lambda ごと | 9.6 秒 | +1.6e-09 |
| sklearn、`precompute=True`(n > p での `'auto'` の選択) | 11.6 秒 | +1.6e-09 |
| celer を lambda ごと | 13.5 秒 | 0 |
| skglm を lambda ごと | 14.5 秒 | +2.8e-17 |
| cuML を lambda ごと、GPU | 53.6 秒 | +9.1e-07 |

全行を他に何も走っていない機械(20 スレッドで負荷 2)で一度に取り、
3 回実行の最良値(scikit-learn 1.9.1、celer 0.7.4、skglm 0.5、CUDA 12.9
上の cuML 26.08、全部同じ venv)。`Lasso` 自身の既定は `precompute=False`
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

#### 速度をメモリに戻す

上の速さはどれも、p × p の Gram 行列のメモリと引き換えに得たものです。もう一方の選択が
`examples/kernel-only/lasso-kernel.scm` です。残差形の座標降下で、X の
ほかに n ベクトルを 1 本だけ持ち、座標ごとに X の列を 2 回読む —
scikit-learn の `Lasso(precompute=False)` の中身と同じアルゴリズムで、
メモリを目的(`--objective memory`)にしたとき残るのはこのプログラムです(covariance 書換えこそが
p × p ブロックを割り当てる一歩なので)。両形は同じ導出の両端で、
`--derive` が `lasso-kernel.scm` を Gram 形に変えます。カーネルは本体の
先頭で形を宣言し(`(with-arrays ((x (p n)) (resid (n)) ..) ..)`。
素の翻訳には何の影響もありません)、導出は平坦なループを配列代数へ
持ち上げ、残差が X の行のスカラー倍で更新され別の行との内積でしか
読まれないことを見て、残差を Gram 行列で保守するメモ `c = X'r` に置き
換えます。カーネルは動かなかった座標の残差更新を飛ばし、`tol` より大きく動いた
座標のなかった掃引で止まるので、その両方が手つかずのまま `c` の更新と導出物の掃引
ループへ持ち越されます。差分化が外へ出すループ入れ子は配列全体の積に
縮約(`contract`、numpy の einsum。各添字をそれが走る軸に名前で載せる)に
畳まれます(`derive: lasso: raise differencing matmul guard`): Gram
`(array-set! g (contract (i) (k1 k2) (x k1 i) (x k2 i)))`、メモの構築
`(array-set! c (contract (i) (k) (x k i) (resid i)))`、残差の復元
`(array-dec! resid (contract (j) (i) ((- beta b0) j) (x j i)))` — multi-task
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
導出形は無条件には採られません。導出形は残差(n 個。X の行の長さ)を
メモ `c = X'r`(p 個)と、O(np²) で作る p × p の Gram に取り替えるもので、
これが得になるのは p < n のときだけです。形は宣言から読みます。X は
`(p n)` なので、導出は導出後の本体を `(if (< p n) ..)` の下に置き、
else 側には書かれたままの掃引を残します(ログの `guard`)。これは
scikit-learn の `precompute='auto'` の規則(`n_samples > n_features`
なら Gram)を、手で書かずに素の座標降下から導出したものです。
`probe/derive-lasso-wide.scm`(p > n)が導出後の翻訳の else 側を検査します。
X の向きも決め打ちではありません。`probe/derive-lasso-col.scm` は X を
n 行 p 列(numpy の C 順)で持つので掃引は列 `(col x j)` を歩きますが、
導出は同じメモと guard を、上の 3 つの積の代わりに `x' x`、`x' r`、
`r -= x d` で出し、転置フラグを反転した同じ `dsyrk` と `dgemv` に下ります。
multi-task カーネルを同じ向きで持ったもの(`probe/derive-mt-col.scm`、残差を
n 行 T 列で持ち列ごとに更新)も同様に `R'X`、`X'X`、`R -= X (W - W0)` に
導出されます。階数も固定ではありません。`probe/derive-mt3.scm` はタスクを
`nb × nt` の格子に並べるので、係数は `p × nb × nt`、残差は `n × nb × nt`、
タスクの残差は fiber `R[:,b,t]` です。導出は `C[b,t,j] = X[:,j] . R[:,b,t]`
(`nb × nt × p` の表)をメモにし、復元用に `p × nb × nt` の写しを持ち、
メモの構築と復元を、他の軸を平坦化すれば行列積になる形 — `R` を
`n × (nb nt)` と読んだ `R'X`、`W` を `p × (nb nt)` と読んだ `R -= X (W - W0)`
— で、3 階の名前をその行列として再宣言した入れ子の scope の下に書きます。
`--blas` にはそれが `dgemm` 2 回に見えます。
`x += a` でも同じです。残差を `X beta - y` として `r += x_j (bnew - old)`
で更新するカーネルは `array-inc!` に持ち上がり、差分化はメモを `+G d`
だけ動かし、`X'(beta - b0)` を足し戻して復元します
(`probe/derive-lasso-inc.scm`)。同じ作業ベクトルを一つの掃引で足しも
引きもするものには触れません。
`bench/lasso-memory-compare.py` は両形を scikit-learn の両形と*等しい
仕事*で比べます。列に AR(1) 相関(ρ 0.9)を入れて降下が現実的な
掃引数になるようにし、その数 S は scikit-learn 自身の収束が決め、
全行が同じ λ(0.01 λmax)でちょうど S 回まわす。CPU 1 コア、X は
双方とも自分の配置で事前に渡す。`bench/resid-cd.cu` は残差形の
座標ステップの長さ n のループ 2 本を GPU 全体に分散し、間にグリッド
バリアを置いたもの — 計測用の手書きで、翻訳出力ではありません。

| ソルバ(S = 43 / 35 / 44 / 29 掃引)          | 1,800 × 200 | 5,000 × 1000 | 100,000 × 200 | 100,000 × 500 |
|-----------------------------------------------|-------------|--------------|---------------|---------------|
| sklearn `Lasso(precompute=False)`             | 0.006 秒    | 0.13 秒      | 1.05 秒       | 1.9 秒        |
| `lasso-kernel.scm`、`-O3 -march=native`       | 0.016 秒    | 0.26 秒      | 1.44 秒       | 2.5 秒        |
| `lasso-kernel.scm`、同上 + `-ffast-math`      | 0.005 秒    | 0.13 秒      | 1.09 秒       | 1.9 秒        |
| 残差形 GPU(`resid-cd.cu`)                   | 0.034 秒    | 0.17 秒      | 0.88 秒       | 1.5 秒        |
| sklearn `Lasso(precompute=True)`              | 0.002 秒    | 0.069 秒     | 0.11 秒       | 0.42 秒       |
| `CovLasso`、Gram 構築込み                     | 0.002 秒    | 0.067 秒     | 0.10 秒       | 0.40 秒       |
| `lasso-kernel.scm --derive`、積はループ入れ子 | 0.032 秒 | 3.0 秒       | 3.0 秒        | 18.6 秒       |
| `lasso-kernel.scm --derive --blas`、`-lopenblas` | 0.002 秒 | 0.067 秒     | 0.11 秒       | 0.42 秒       |
| `lasso-kernel.scm --derive --cublas`、アップロード込み | 0.002 秒 | 0.019 秒 | 0.049 秒      | 0.11 秒       |
| `lasso-auto.scm --blas`、手書きの Gram 経路   | 0.002 秒    | 0.067 秒     | 0.11 秒       | 0.42 秒       |
| `lasso-auto.scm --cublas`、アップロード込み   | 0.001 秒    | 0.019 秒     | 0.047 秒      | 0.105 秒      |
| 追加メモリ、残差形 / Gram 形                  | 14 KB / 312 KB | 39 KB / 8 MB | 781 KB / 312 KB | 781 KB / 2 MB |

全行を他に何も走っていない機械(負荷 1 前後)で一度に取った値です(各行は
3 回の最良値、スクリプト全体を 2 回)。`--blas` 付きの導出物、手書きの
`lasso-auto.scm --blas`(`lasso-cov.scm` の `cov-descend` を、同じ 3 つの
積を matmul 形で手書きした前処理の後ろに置いたもの、下記)、パッケージの
`CovLasso` は同じ `dsyrk` の上の同じ掃引ループで、全形状で同時間です。
導出が省くのは 3 つの積を書く手間であって、時間ではありません。
`--cublas` は X のアップロード込みでさらに 3〜4 倍、素の `--derive` 行の
ループ入れ子の Gram は最大形状で BLAS の 45 倍遅い。

`examples/kernel-only/lasso-auto.scm` は scikit-learn の
`precompute='auto'` と同じ選択を手で書いたものです。観測数が特徴数より
多ければ(`n > p`)Gram 行列を作って `lasso-cov.scm` の `cov-descend` を
その上で走らせ、そうでなければ `lasso-kernel.scm` の `lasso` が残差を
持ち回ります。どちらも include で取り込むので、このファイルにあるのは
分岐と Gram の準備だけです。3 つの積は最初から `matmul` 形で書いてある
ので `--blas` / `--cublas` は導出物のときと同じようにそれを下ろします。
`lasso-kernel.scm --derive` が今出すもの(導出は同じ `n > p` の分岐を
自分で出す、上記)を手で書いたもので、導出物と読み比べる参照として
残してあり、翻訳は `--derive` なしで行います(かけても残差経路の中に
冗長な guard がもう一つ入るだけです)。`n <= p` で残差経路を残すのは、
O(np^2) の Gram 構築を O(p^2) の掃引で回収できない領域だからです。
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
dyadic なデータ(整数の要素、2 のべき乗のノルム)で両経路をテストスイートで走らせます(素の翻訳、`--blas`、
`--cublas`)。

つまりメモリ優先の形は scikit-learn と同速で走ります — 同じアルゴリズム
なので当然ですが、計測が見えるようにした条件が 2 つあります。カーネル
は動かなかった座標の残差更新を飛ばさなければならない(scikit-learn は
飛ばす。疎な解ではほとんどの座標がそう。カーネルは今それをしており、
入れる前は 1.5–2.5 倍遅かった)。そしてコンパイラに内積の加算の並べ
替えを許さなければならない(翻訳器は厳密な逐次和を書き、gcc はそれを
ベクトル化しない。scikit-learn の BLAS `ddot` はその順序を約束して
いない)。GPU は残差形を n=100,000 で scikit-learn の 1.2–1.3 倍に
し、それより下では負けます — 座標ごとの 2 回のグリッドバリアが、囲って
いる乗算より高い。座標ステップは縮約で、バリアは CPU が
決して払わない代金です。そして Gram 形は n=100,000 でそのどちらよりも
5〜10 倍速く、代金は 312 KB〜2 MB。単発 fit では当方の Gram 形と scikit-learn
の `precompute=True` は同速です(上の CV の勝ちは Gram の引き算と
warm path であって、このカーネルではありません)。全行が scikit-learn
の参照と 1e-15 で一致(Gram の 2 行は 1e-13、Gram の和の順序が違う)。

各部分の仕組みは後述します。Python 包装は「PyPI からソルバを入れる」、
境界コピーなしの `-M` インタフェースは「速い lasso を Python から呼ぶ」、
CUDA プロファイルは「GPU 上での実行」を参照してください。

## PyPI からソルバを入れる

ソルバには専用のパッケージがあるので、Python の利用者は Racket も
このリポジトリも必要としません。

```console
$ pip install scm2cpp-learn     # scikit-learn の推定器およそ 50 個(旧名 scm2cpp-lasso)
$ pip install scm2cpp-tfs       # 移動平均による特徴選択
```

両方とも公開済みです —
[scm2cpp-learn](https://pypi.org/project/scm2cpp-learn/) と
[scm2cpp-tfs](https://pypi.org/project/scm2cpp-tfs/)。このファイルの
冒頭の例は公開版に対してそのまま動きます。

```python
from scm2cpp_learn import CovLasso
model = CovLasso(X, y)
path = model.fit_path(model.lambda_grid())

from scm2cpp_learn import DerivedLasso     # 導出物そのものの C++。X と y を渡す
path = DerivedLasso(X, y).fit_path(model.lambda_grid())

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

両者とも暖かく始めるなら両者は互角で、解は丸めの範囲で一致します。差が開くのは
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

数値はこのページの冒頭の表にあります。両者とも冷たく始めるなら、4,096 個の罰則
すべてで、翻訳カーネルは 1 コアで scikit-learn の約 16 倍(0.95 秒 対 15.2 秒)、
GPU バッチはそこからさらに約 21 倍(0.045 秒、scikit-learn の約 340 倍)です。
厳しい方の許容誤差で解いているのは翻訳側です。
nvcc とデバイスがある環境で `run-tests.sh` が走らせる検査は、同じ
プログラムの小さな事例です。

# Scheme のカーネルから `pip install` まで

*[English (PACKAGING.md)](PACKAGING.md)*

scm2cpp の subset で書いた数値計算の関数を、C++ コンパイラだけで入り
Racket の要らない Python パッケージにする手順です。ここにある 2 つの
パッケージ(`scm2cpp-lasso/`、`scm2cpp-tfs/`)はこの手順で作ってあるので、
ゼロから始めずにその配置を写してください。

## 1. `-M` が入口を出せる形でカーネルを書く

`-M` は型が具体的に決まった関数ごとに `extern "C"` のラッパと ctypes の
ローダを出します。カーネルはそういう関数として書きます。

- `main` は書かない。入口 1 つにつき関数 1 つ、結果は出力引数に残して
  `0` を返す(関数の返り値もスカラーなら渡りますが、ベクタの返り値は
  渡りません)。
- 配列は平坦な `double` のベクタで添字は手計算: 列優先の設計行列なら
  `x[j*n+i]`、`(vector-ref x (+ (* j n) i))`。浮動小数点に決まる制約の
  ない引数は一度 `(* 1.0 n)` を掛けて `int` にならないようにする。
- 大きさは引数(`n`, `p`)で持ち、ベクタリテラルで固定しない。固定長の
  `(make-vector 10 0.0)` は `std::array` になり、ラッパが任意の numpy
  配列を受けられなくなる。
- テンプレート引数(`Unknown_typeNNNType`)が残った関数は `-M` が名前入りの
  コメントを出して飛ばす。呼び出し箇所か `(* 1.0 ..)` を与えて型を閉じる。
- 共有する定義は `(include "file.scm")` で取り込む(`soft-threshold.scm`
  がそれ)。コピーしない。
- `--derive` にかけるなら本体の先頭で `(with-arrays ((x (p n)) (resid (n))
  ..) ..)` と形を宣言する(`examples/kernel-only/lasso-kernel.scm` の
  とおり)。宣言は素の翻訳には何の影響もない。

パッケージにする前に試す(完全な例は `examples/kernel-only/README.md`):

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M kernel.scm      # kernel.hpp .cpp _capi.cpp .py
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libkernel.so kernel_capi.cpp
$ python3 -c 'import kernel; kernel.my_entry(x, out, n, p)'  # kernel.py は隣の libkernel.so を読む
```

生成された `kernel.py` は入ってくる配列を連続な `float64` にしてその場で
書き換えるので、出力は連続な配列を先に確保して渡します。

## 2. パッケージの配置

`scm2cpp-lasso/` を雛形にします。部品は次のとおり。

| ファイル | 役割 |
|---|---|
| `regenerate.sh` | Scheme を `src/<pkg>/_generated/` に翻訳し(`-M`、必要なら `--derive`/`--blas` も)、`scm2cpp.hpp`(と `scm2cpp-blas.hpp`)を隣に写し、ローダの `ctypes.CDLL(...)` の行を `_libfind` 経由に書き換える。Racket が要る唯一の手順で、出力はコミットする。 |
| `src/<pkg>/_generated/` | 翻訳器の出力。コミットしてあるので `pip` には C++17 コンパイラしか要らない。 |
| `src/<pkg>/_libfind.py` | インタプリタの ABI タグがどうであれ、語幹でビルド済み拡張を見つける。任意の変種のどれが入ったかも返す。 |
| `setup.py` | `_capi.cpp` ごとに `Extension` 1 つ、`include_dirs=[_generated]`。任意の部品(`nvcc` による CUDA ライブラリ、コンパイル・リンクの検査による BLAS 版)は試して駄目なら飛ばす。必須にしない。 |
| `pyproject.toml` | メタデータ、依存は `numpy`、`package-data` に `_generated/**/*.hpp` と `*.cpp` を列挙して sdist に入れる。 |
| `src/<pkg>/__init__.py` | 利用者が呼ぶクラス。形を検査し、配列をカーネルの望む配置にし(列優先の設計行列なら `np.ascontiguousarray(X.T)`)、出力を先に確保し、ローダの関数を呼び、結果を reshape する。 |
| `check-*.py` | 乱数データで参照(numpy、scikit-learn、またはパッケージ自身の別経路)と突き合わせて差を出す。再インストールのたびに venv で走らせる。 |

`src/` の下を変えたら再インストール(`pip install .`、`-e` は使わない)。
C++ はインストール時にコンパイルされ、ローダは入口を名前で束縛するので、
古いライブラリはエラーではなくシンボル欠落として現れます。

## 3. カーネルをこのリポジトリに置くなら

- Scheme は `examples/kernel-only/` に置き、`FILES.md` / `FILES.ja.md` に
  行を足し、`regenerate.sh` はそこから写す。
- `run-tests.sh` に、`-M` で翻訳して `.so` を作り小さな Python の比較を
  走らせるケースを足す(`pymodule-lasso` と `pymodule-derived` が写す
  対象)。署名の変化をパッケージより先に suite が捕まえる。
- `CHANGES.ja.md` に番号付きの節、版は `pyproject.toml` と `__init__.py` を
  同時に上げる。

## 4. 公開

```console
$ cd python/<pkg> && python3 -m build        # コミット済みの C++ から sdist と wheel
$ python3 -m twine upload dist/*             # 自分の PyPI トークンで
```

wheel はビルドしたインタプリタと機械に固有なので、ほとんどの利用者が
使うのは sdist です。

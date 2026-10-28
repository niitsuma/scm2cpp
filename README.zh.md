# Scm2Cpp

[![tests](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml/badge.svg)](https://github.com/niitsuma/scm2cpp/actions/workflows/tests.yml) [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/niitsuma/scm2cpp/blob/master/notebooks/compare-sklearn.ipynb)

*[English](README.md) · [日本語](README.ja.md)*

Scm2Cpp 把 Scheme 的一个子集翻译成人可以阅读和修改的 C++。用它朴素地写出
scikit-learn 的机器学习算法，得到的就是快的实现：翻译器从朴素的写法推导出快的
形式（把 Gram 矩阵提到坐标下降之外、循环不变的乘积只算一次），把矩阵乘积交给
BLAS 或 cuBLAS，并把可并行的循环变成 CUDA 核函数。这些估计器以 `scm2cpp-learn`
的名字发布在 PyPI 上（0.17.0 及以前叫 `scm2cpp-lasso`，用旧名也能安装），Linux、macOS 和 Windows 都有预编译的 wheel（不需要编译器，
也不需要 Racket）。

> 本页是英文 README 开头部分的中文版。更详细的文档（`docs/`）目前只有英文和日文。

## 加速了哪些机器学习算法

每一个都是 scikit-learn 自己的算法，用这个子集写成，并与 scikit-learn 的迭代次数和
结果逐一核对。时间是与单核 scikit-learn 的比值（i9-10900X，设备一栏用 RTX 4090，
scikit-learn 1.9）；测量条件见右侧所链接的章节（英文）。

| 算法，n x p | `scm2cpp_learn` 的类 | 相对 scikit-learn | 方法 | 章节 |
|---|---|---|---|---|
| Lasso，4,096 个惩罚参数各自从零开始，1,800 x 200 | `CovLasso`（`fit_path_batch`） | 单核 16 倍，GPU 340 倍（容差本方 1e-8，对方 1e-4） | 在 Gram 矩阵上做下降 | [Example: a fast lasso](docs/lasso.md#example-a-fast-lasso-from-scheme-to-pip-and-the-gpu) |
| Lasso 路径，20 个惩罚参数，100,000 x 500 | `DerivedLasso`（`fit_path`） | 6.7 倍 | 由朴素的下降推导而来（`--derive --cublas`） | [第一个例子：lasso](#第一个例子lasso) |
| RFE(LinearRegression)，20,000 x 500 | `GramRFE(0.0, ..)` | 1,047 倍 | Gram 矩阵，每删一个特征就更新一次 Cholesky 因子 | [Feature selection by F statistics and RFE](docs/benchmarks.md#feature-selection-by-f-statistics-and-rfe-and-the-devices-gram) |
| f_regression，100 个目标变量，20,000 x 1,000 | `f_regression` | 49 倍 | 设备上的一次乘积 | [Feature selection by F statistics and RFE](docs/benchmarks.md#feature-selection-by-f-statistics-and-rfe-and-the-devices-gram) |
| RidgeCV，50 个 alpha，20,000 x 500 | `GramRidgeCV` | 29 倍 | 一次特征分解，所有 alpha 的留一误差由两次矩阵乘积得到 | [RidgeCV from one eigenproblem](docs/benchmarks.md#ridgecv-from-one-eigenproblem) |
| KernelPCA(rbf)，5 个成分，6,000 x 20 | `GramKernelPCA` | 3.5 倍 | 用 dgemm 的子空间迭代（scikit-learn 用 ARPACK） | [KernelPCA by subspace iteration](docs/benchmarks.md#kernelpca-by-subspace-iteration) |
| LinearDiscriminantAnalysis，200,000 x 100，5 个类 | `GramLDA` | 52 倍 | 把 svd 求解器的 n x p SVD 换成 Gram 矩阵的 p x p 特征分解 | [LDA from the Gram matrix](docs/benchmarks.md#lda-from-the-gram-matrix) |
| TruncatedSVD，10 个成分，200,000 x 100 | `GramTruncatedSVD` | 5.4 倍（相对 arpack 20 倍） | 由 X'X 得到精确 SVD（scikit-learn 的默认方法是近似） | [TruncatedSVD from the Gram matrix](docs/benchmarks.md#truncatedsvd-from-the-gram-matrix) |
| CCA / PLSRegression，50,000 x 500 -> 10 | `GramCCA` / `GramPLSRegression` | 109 倍 / 61 倍 | 在 X'X、X'Y、Y'Y 上做 NIPALS（数据行只读一遍） | [PLS and CCA over the cross products](docs/benchmarks.md#pls-and-cca-over-the-cross-products) |
| FactorAnalysis，200,000 x 100，10 个因子 | `GramFactorAnalysis` | 62 倍（对 lapack 为 286 倍） | 每次迭代的 n x p SVD 改为协方差上的 p x p 特征值问题 | [FactorAnalysis over the covariance](docs/benchmarks.md#factoranalysis-over-the-covariance) |
| LinearRegression，500,000 x 100 | `GramLinearRegression` | 19 倍 | 用 Cholesky 解正规方程，并以条件数估计把关 | [LinearRegression from the Gram matrix](docs/benchmarks.md#linearregression-from-the-gram-matrix) |
| TruncatedSVD，稀疏 200,000 x 200，5% 非零 | `GramTruncatedSVD` | 8.1 倍（对 arpack 为 15 倍） | 由每行的外积求 X'X（`csr-gram`） | [Sparse X through the Gram matrix](docs/benchmarks.md#sparse-x-through-the-gram-matrix) |
| GraphicalLasso，p = 50 | `CDGraphicalLasso` | 45 倍 | `--blas` | [GraphicalLasso, KMeans and RANSAC](docs/benchmarks.md#graphicallasso-kmeans-and-ransac-measured-against-sklearn) |
| HuberRegressor / LogisticRegression / PoissonRegressor，200,000 x 100 | `LBFGSHuberRegressor` / `LBFGSLogisticRegression` / `LBFGSPoissonRegressor` | 22 倍 / 15 倍 / 10 倍 | L-BFGS-B，`--cuda` | [GPU kernels from the translator](docs/benchmarks.md#gpu-kernels-from-the-translator---cuda) |
| LassoLarsIC，200,000 x 100 | `GramLassoLarsIC` | 20 倍 | 由 Gram 矩阵计算信息准则 | [Perceptron, passive-aggressive, ARD, LassoLarsIC](docs/benchmarks.md#perceptron-passive-aggressive-ard-lassolarsic-and-the-l1-linear-svm) |
| FastICA / GaussianMixture，200,000 x 20 | `ParallelFastICA` / `EMGaussianMixture` | 6.7 倍 / 3.1 倍 | `--cuda` | [GPU kernels from the translator](docs/benchmarks.md#gpu-kernels-from-the-translator---cuda) |
| LogisticRegressionCV，2,000 x 20 / LarsCV，2,000 x 50 | `LBFGSLogisticRegressionCV` / `GramLarsCV` | 6.6 倍 / 6.6 倍 | 各折共用一个 Gram 矩阵，热启动 | [GLMs, the cross-validated estimators](docs/benchmarks.md#glms-the-cross-validated-estimators-and-theil-sen) |
| ARDRegression，20,000 x 100 | `CovARDRegression` | 3.1 倍 | X'X 只算一次（`--derive` 能自动推导出来） | [Loop-invariant products, derived](docs/benchmarks.md#loop-invariant-products-derived) |
| LinearSVC，100,000 x 200 | `LinearSVM` | 1.9 倍 | 用子集写成的 liblinear 求解器 | [The SVM](docs/benchmarks.md#the-svm-measured-against-sklearn) |
| NMF (cd)，20,000 x 1,000，30 | `CDNMF` | 1.8 倍 | 推导而来（`--derive --cublas`） | [NMF, derived](docs/benchmarks.md#nmf-derived-measured-against-sklearn) |

### 替换 scikit-learn 的估计器

大多数类接受与 scikit-learn 估计器同名的参数（其中的一部分），并且有同样的
`fit` / `predict` / `transform`、`coef_`、`n_iter_` 等，所以只需改一行 import：

```python
from scm2cpp_learn import LBFGSLogisticRegression as LogisticRegression

clf = LogisticRegression(C=1.0).fit(X, y)   # 与 scikit-learn 相同的迭代次数和系数
```

不一样的有：`CovLasso`、`CovRidge` 和 `DerivedLasso` 在构造函数里接收数据，一次解出
整组惩罚参数（`fit_path` / `fit_path_batch`；对应 scikit-learn 中对每个惩罚参数循环调用
`fit_intercept=False` 的 `Lasso(alpha=a).fit`）；`GramRFE` 接收岭回归的惩罚参数而不是
一个估计器（`RFE(Ridge(alpha=1.0), n_features_to_select=20)` 对应
`GramRFE(1.0, n_features_to_select=20)`，`LinearRegression` 对应 `alpha=0`）。
所有类及其对应的 scikit-learn 估计器列在 Python 包 README 的
[估计器一览表](python/scm2cpp-learn/README.md#estimators-at-a-glance)中。

**与 scikit-learn 的兼容性。** 从 0.14.0 起，估计器继承 scikit-learn 的
`BaseEstimator` 和相应的 mixin（scikit-learn 本身仍是可选依赖），因此 `clone`、
`GridSearchCV`、`Pipeline`、`cross_val_score` 都可以直接使用，带 `fit(X, y)` 的
44 个估计器全部通过 `check_estimator`。在构造函数里接收数据的类各自配有一个
`fit(X, y)` 形式（`CovLasso` 对应 `GramLasso`，`DerivedLasso` 对应 `DesignLasso`，等等）。代价是输入检查：每次调用约 10 us，
大数据时为遍历一次 X 的时间；测量结果见 Python 包 README 的
[兼容性一节](python/scm2cpp-learn/README.md#scikit-learn-compatibility)。

### 安装

```console
$ pip install scm2cpp-learn
```

| 平台 | pip 安装的内容 |
|---|---|
| Linux x86_64（glibc 2.28 或更新） | wheel，内含 OpenBLAS |
| macOS 14 或更新，Apple 芯片 | wheel，内含 OpenBLAS |
| Windows x86_64 | wheel，不含 BLAS（循环版本：结果相同，矩阵乘积较慢） |
| 其他（Linux aarch64、Intel Mac、musl） | sdist，安装时编译：需要 C++17 编译器 |

这些库通过 ctypes 加载，所以同一个 wheel 适用于 Python 3.8 及以后的所有版本；每个
wheel 都在 Python 3.12 上安装测试过，Linux 版还在 3.13 和 3.14 上测试过。wheel 里
不含 GPU 代码：要用 CUDA 版本，请在 `nvcc` 在 PATH 中的机器上从 sdist 安装
（`pip install --no-binary scm2cpp-learn scm2cpp-learn`）。翻译器本身的安装见
[docs/translator.md](docs/translator.md#installation)（英文）。

### 与 Intel sklearnex 的比较

sklearnex（scikit-learn-intelex）也加速了其中一些估计器。在单核对单核时，除 Ridge 外，本包在
所有比较项目（LogisticRegression、PCA、SVC、SVR、RFE(Ridge)）上都比它快（1.4 到 106 倍；
Ridge 为 0.8 倍）。双方都使用 20 个核时（本包的循环用 OpenMP，矩阵乘积用 MKL），本包在
Ridge（2.3 倍）、PCA（1.4 到 1.6 倍）、设备版逻辑回归（1.8 倍）和 RFE（116 倍）上领先，
CPU 版逻辑回归大致持平，SVM 则落后（0.4 到 0.5 倍：SMO 是顺序算法）。sklearnex
的计算与 scikit-learn 并不相同（L-BFGS 迭代 12 次而 scikit-learn 是 6 次，系数相差
6e-3），本包则与 scikit-learn 一致。sklearnex 没有 lasso。表格和测量条件见
[Python 包的 README](python/scm2cpp-learn/README.md#against-intels-sklearnex)（英文）。

想在 Colab 的机器上一键复现这些比较，请点击顶部的徽章打开
`notebooks/compare-sklearn.ipynb`（CPU 运行时安装 wheel；GPU 运行时还会编译 CUDA 版本）。

并非每种情况都更快：50,000 x 500 的 PCA 和大 n 的 KMeans 与 scikit-learn 一样快或更慢，
相应章节中有说明。

## 第一个例子：lasso

执行 `pip install scm2cpp-learn` 后，`DerivedLasso(X, y).fit_path(lambdas)` 运行的 lasso，
其 C++ 是翻译器*推导*出来的：源代码是朴素的残差形式的坐标下降
（`examples/kernel-only/lasso-design.scm`，在 numpy 原样存放的 X 上的平坦循环，没有任何
Gram 矩阵），`--derive` 把它变成协方差形式，把 Gram 矩阵提到整条惩罚路径之前，
`--blas` / `--cublas` 再把其中的三个矩阵乘积交给 BLAS 或 cuBLAS。没有任何部分是在 Gram
矩阵的层面上手写的，也不需要在 numpy 里做任何准备。在 RTX 4090 上，cuBLAS 版求解 20 个
惩罚参数的路径，在 5,000 x 1,000 / 100,000 x 200 / 100,000 x 500 上分别用 0.024 / 0.052 /
0.11 秒，而单核、默认容差的 scikit-learn `lasso_path(precompute=True)` 用 0.100 / 0.236 /
0.759 秒，即 4.2 倍、4.5 倍、6.7 倍（给 scikit-learn 用满 20 个 BLAS 线程时为 2.2 倍、4.5 倍、
4.0 倍，因为它只有 Gram 乘积能并行）；CPU 版与旁边手写的 `CovLasso` 一样快。表格、测量
条件以及与高精度参考解的差异见 `python/scm2cpp-learn/README.md`。推导的每一条规则按触发
顺序、附代码链接，写在 `DERIVATION.md` 中。

## 翻译出来是什么样子

传统的 Scheme 编译器输出只给机器看的 C，而 Scm2Cpp 不给 Scheme 的值任何运行时表示：
整数变成 `int`，向量变成 `std::array<double,1025>`，`(car x)` 变成 `car(x)`。类型来自
整个程序的类型推断；推断不出来的部分成为 C++ 的模板参数。

```scheme
(define (square x) (* x x))
(define (average x y) (/ (+ x y) 2.0))
(define (improve guess x) (average guess (/ x guess)))
```

变成

```cpp
double square( double x )                 { return (x*x) ; }
double average( double x, double y )      { return ((x+y)/2.0) ; }
double improve( double guess, double x )  { return average(guess,double((x/guess))) ; }
```

## 文档

- [docs/lasso.md](docs/lasso.md)（英文）/ [docs/lasso.ja.md](docs/lasso.ja.md)（日文）—— lasso 的细节
- [docs/benchmarks.md](docs/benchmarks.md) / [docs/benchmarks.ja.md](docs/benchmarks.ja.md) —— 各估计器与 scikit-learn 的比较
- [docs/translator.md](docs/translator.md) / [docs/translator.ja.md](docs/translator.ja.md) —— 翻译器本身：安装、命令行与选项、Scheme 子集、测试
- [python/scm2cpp-learn/README.md](python/scm2cpp-learn/README.md) —— Python 包：所有估计器、与 sklearnex 的比较
- `DERIVATION.md` —— `DerivedLasso` 是如何推导出来的

## 许可证

MIT 许可证，见 `LICENSE`。部分文件源自 Aubrey Jaffer 的 Schlep 和 SLIB 以及 Paul Graham
《On Lisp》中公开的工具函数；`vendor/rkanren` 是随附的第三方库。它们保留各自的宽松许可，
全文附在各文件开头，并记录在 `NOTICE` 中。

## 引用

引用时请注明本仓库和所用的提交（元数据见 `CITATION.cff`）。`tfs-` 开头的 kernel（移动平均设计，[`scm2cpp-tfs`](https://pypi.org/project/scm2cpp-tfs/)）所用的时间序列特征选择见 H. Niitsuma, *An Extension of Temporal Feature Selection*, Zenodo, 2026, [doi:10.5281/zenodo.18909363](https://zenodo.org/records/18909363)。

# Examples

## tfs-lasso.scm: temporal feature selection over moving averages

Temporal feature selection describes a signal as a sparse combination of
moving averages of an underlying sequence at various window lengths, and
uses lasso to find which windows matter. This example builds a synthetic
instance whose answer is known, so the whole pipeline can be checked
end to end:

1. A pseudo-random base sequence `x` of 400 points.
2. A signal `y` composed from the moving averages of `x` at two window
   lengths the selection step is not told about: `w=5` with weight `2.0`
   and `w=20` with weight `-1.5`.
3. Every window length from 1 to 40 offered as a candidate feature.
4. Lasso coordinate descent over all 40 candidates.

The moving averages are differences of a prefix-sum array `ps`, and `ps`
is written as the naive O(n^2) box-sum nest on purpose: it is the shape
the `-I` option recognises and rewrites to a rank-1 summed-area table.

```console
$ racket scm2cpp-file.scm -t scm2c.typ examples/tfs-lasso.scm       # plain
$ racket scm2cpp-file.scm -t scm2c.typ -I x examples/tfs-lasso.scm  # rewritten
$ g++ -O2 -std=c++11 -I. -include boost/operators.hpp -include boost/optional.hpp \
      -o tfs-lasso examples/tfs-lasso.cpp
$ ./tfs-lasso
```

Both runs print the same selection:

```
selected windows (|beta|>1e-6):
  w=1  beta_hat=0.000436075
  w=5  beta_hat=1.96512
  w=20  beta_hat=-1.45172
  w=23  beta_hat=-0.00578116
  w=25  beta_hat=-0.0072154
beta at true windows: w=5 -> 1.96512   w=20 -> -1.45172
max|beta| among the other 38 windows = 0.0072154
max|y-yhat| = 0.0997609
```

The two windows the signal was actually built from are recovered with
coefficients close to the true `2.0` and `-1.5`, every other window's
coefficient is two orders of magnitude smaller, and the signal is
reconstructed to within 0.1. With `-I x` the generated code holds `x` as
`scm2cpp::integral_image<double,1>` and computes each prefix sum as one
query.

`tfs-lasso-reference.py` repeats the same construction in NumPy with the
same generator and solves it with scikit-learn's `Lasso`; its
coefficients agree with the printed ones to six decimal places, which
checks the translated coordinate descent against an independent
implementation.

The kernel also shows the inferred const distinction: `lasso`'s design
matrix and column norms come out as `const boost::array<...>&`, while
the coefficient and residual vectors, which the sweep updates in place,
stay non-const.

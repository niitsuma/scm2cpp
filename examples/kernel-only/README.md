# A kernel with no main

`lasso-kernel.scm` is meant to be called from elsewhere -- Python, or any
C++ of your own -- rather than run on its own. It therefore has no `main`,
and nothing in it says how long its arrays are.

Inference reads the array parameters off how they are used: indexing with
`vector-ref` says the parameter is a vector, and what is done with the
element says the element is a `double`. The extent stays open, so the
parameters come out as `std::vector<double>`, which `-M` can carry across
the C ABI as a pointer and a length:

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M examples/kernel-only/lasso-kernel.scm
$ g++ -O2 -std=c++11 -shared -fPIC -I. -include boost/operators.hpp \
      -include boost/optional.hpp -o liblasso-kernel.so lasso-kernel_capi.cpp
```

```python
import numpy as np, lasso_kernel
beta, resid = np.zeros(p), y.copy()
lasso_kernel.lasso(xd, beta, resid, xnorm, 0.02, 20000, n_obs, p)
# beta now holds the coefficients
```

The same kernel used by a program that *does* create its arrays with
`make-vector` gets `boost::array<double,N>&` parameters instead: a known
extent is the better answer, and inference prefers it wherever a call
site supplies one. `examples/tfs-lasso.scm` is that case.

Checked against scikit-learn's `Lasso` on the same problem: the
coefficients agree to 5e-11.

## lasso-fused.scm: the design matrix that is never built

In temporal feature selection the design matrix is not arbitrary: column
j is the moving average of one base sequence at window j+1, so

    X[row][j] = (ps[t] - ps[t-w]) / w,   t = wmax + row

is determined by the prefix sums `ps` and the window length. The solver
can recompute an element wherever it needs one and never allocate X at
all -- reading n numbers per sweep where the ordinary form reads n*p.
`lasso-fused.scm` does that, and agrees with scikit-learn's `Lasso` to
2e-13 on the same problem.

Two lessons from measuring it, both now reflected in the code:

- Dividing by the window once per element costs more than the memory the
  fusion saves. The reciprocal is computed once per column and
  multiplied.
- Reading through a small helper function cost about three times the
  loop it was helping, because generated functions were emitted into the
  header without `inline` and were not expanded. They now carry `inline`,
  which is also what lets the header be included from more than one
  translation unit at all.

Whether the fused form is faster than the materialised one depends on
the machine and the shape of the problem, and this repository has no
measurement worth quoting: the machine available while it was written
never went idle (load above 30 throughout), and repeated runs of the
same case varied by nearly 50%. The claim to take from here is the one
that is not about speed -- the fused form computes the same answer while
using O(n) memory instead of O(n*p).

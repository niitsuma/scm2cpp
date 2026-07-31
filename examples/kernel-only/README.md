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

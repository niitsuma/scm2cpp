# scm2cpp-lasso is now scm2cpp-learn

From 0.18.0 the package is published as
[scm2cpp-learn](https://pypi.org/project/scm2cpp-learn/) and imported as
`scm2cpp_learn`: it holds far more than the lasso (RidgeCV, KernelPCA,
LDA, TruncatedSVD, SVMs, mixtures and more, about fifty scikit-learn
estimators translated from Scheme to C++).

```console
$ pip install scm2cpp-learn
```

```python
import scm2cpp_learn
```

This package, `scm2cpp-lasso` 0.18.0 and later, only installs
scm2cpp-learn and keeps `import scm2cpp_lasso` working: the old name is
the new module, with a DeprecationWarning. Versions up to 0.17.0 are the
package under its old name.

The documentation is at
[python/scm2cpp-learn](https://github.com/niitsuma/scm2cpp/tree/master/python/scm2cpp-learn).

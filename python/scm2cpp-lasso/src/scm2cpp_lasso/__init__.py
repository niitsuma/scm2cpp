"""scm2cpp-lasso is now scm2cpp-learn.

The package holds far more than the lasso (RidgeCV, KernelPCA, LDA,
SVMs, mixtures, ...), so from 0.18.0 it is published as scm2cpp-learn
and imported as scm2cpp_learn.  This module stands in for the old name:
``import scm2cpp_lasso`` gives the scm2cpp_learn module itself (every
class, function and submodule), with a DeprecationWarning.
"""
import sys
import warnings

import scm2cpp_learn as _learn

warnings.warn("scm2cpp_lasso has been renamed scm2cpp_learn (pip install scm2cpp-learn); "
              "import scm2cpp_learn instead", DeprecationWarning, stacklevel=2)

# the old name is the new module: attributes, isinstance and submodules
# (scm2cpp_lasso._libfind, ...) all resolve to scm2cpp_learn's
sys.modules[__name__] = _learn

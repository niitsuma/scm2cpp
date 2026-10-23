"""The scikit-learn estimator interface, with scikit-learn optional.

With scikit-learn installed the estimators derive from its
BaseEstimator and mixins, and their inputs go through its
validate_data, so clone, get_params / set_params, GridSearchCV,
Pipeline and check_estimator see ordinary estimators.  Without it
(numpy alone, as the wheels need) a small stand-in gives the same
get_params / set_params / score and the checks that matter for the
kernels: a 2-D float64 C-ordered X, finite values, the feature count
remembered at fit and compared at predict.
"""
import inspect

import numpy as np

try:
    from sklearn.base import (BaseEstimator, ClassifierMixin, RegressorMixin,
                              TransformerMixin, DensityMixin)
    from sklearn.utils.validation import check_is_fitted
    from sklearn.utils.multiclass import check_classification_targets
    try:
        from sklearn.utils.validation import validate_data as _sk_validate
    except ImportError:                     # scikit-learn before 1.6
        def _sk_validate(est, *args, **kw):
            return est._validate_data(*args, **kw)
    HAVE_SKLEARN = True
except ImportError:
    HAVE_SKLEARN = False

    class NotFittedError(ValueError, AttributeError):
        pass

    class BaseEstimator:
        @classmethod
        def _get_param_names(cls):
            sig = inspect.signature(cls.__init__)
            return sorted(p.name for p in sig.parameters.values()
                          if p.name != "self" and p.kind not in
                          (p.VAR_POSITIONAL, p.VAR_KEYWORD))

        def get_params(self, deep=True):
            return {k: getattr(self, k) for k in self._get_param_names()}

        def set_params(self, **params):
            valid = self._get_param_names()
            for k, v in params.items():
                if k not in valid:
                    raise ValueError(f"invalid parameter {k!r} for {type(self).__name__}")
                setattr(self, k, v)
            return self

        def __repr__(self):
            args = ", ".join(f"{k}={v!r}" for k, v in self.get_params().items())
            return f"{type(self).__name__}({args})"

    class ClassifierMixin:
        _estimator_type = "classifier"

        def score(self, X, y, sample_weight=None):
            return float(np.average(self.predict(X) == np.asarray(y),
                                    weights=sample_weight))

    class RegressorMixin:
        _estimator_type = "regressor"

        def score(self, X, y, sample_weight=None):
            y = np.asarray(y, dtype=np.float64)
            r = y - self.predict(X)
            w = None if sample_weight is None else np.asarray(sample_weight)
            ss_res = np.average(r * r, axis=0, weights=w)
            ym = np.average(y, axis=0, weights=w)
            ss_tot = np.average((y - ym) ** 2, axis=0, weights=w)
            return float(np.mean(1.0 - ss_res / ss_tot))

    class TransformerMixin:
        def fit_transform(self, X, y=None, **fit_params):
            return self.fit(X, y, **fit_params).transform(X)

    class DensityMixin:
        _estimator_type = "DensityEstimator"

        def score(self, X, y=None):
            pass

    def check_is_fitted(est, attributes=None):
        if not any(k.endswith("_") and not k.startswith("__") for k in vars(est)):
            raise NotFittedError(f"This {type(est).__name__} instance is not fitted yet; "
                                 "call fit first")

    def check_classification_targets(y):
        if np.asarray(y).dtype.kind == "f" and not np.all(np.mod(y, 1) == 0):
            raise ValueError("Unknown label type: continuous")

    def _as_x(X):
        X = np.ascontiguousarray(X, dtype=np.float64)
        if X.ndim != 2:
            raise ValueError(f"Expected a 2D array, got {X.ndim}D; reshape it")
        if X.shape[0] < 1 or X.shape[1] < 1:
            raise ValueError(f"Found array with shape {X.shape}; a minimum of 1 is required")
        with np.errstate(over="ignore", invalid="ignore"):
            finite = np.isfinite(X.sum()) or np.isfinite(X).all()
        if not finite:
            raise ValueError("Input X contains NaN or infinity")
        return X

    def _sk_validate(est, X="no_validation", y="no_validation", reset=True,
                     multi_output=False, y_numeric=False, dtype=None, order=None,
                     ensure_min_samples=1, ensure_min_features=1, **kw):
        out = []
        if not (isinstance(X, str) and X == "no_validation"):
            X = _as_x(X)
            if X.shape[0] < ensure_min_samples or X.shape[1] < ensure_min_features:
                raise ValueError(f"Found array with shape {X.shape}; a minimum of "
                                 f"{ensure_min_samples} samples and {ensure_min_features} "
                                 f"features is required by {type(est).__name__}")
            if reset:
                est.n_features_in_ = X.shape[1]
            elif X.shape[1] != getattr(est, "n_features_in_", X.shape[1]):
                raise ValueError(f"X has {X.shape[1]} features, but {type(est).__name__} "
                                 f"is expecting {est.n_features_in_} features as input")
            out.append(X)
        if not (isinstance(y, str) and y == "no_validation"):
            if y is None:
                raise ValueError(f"{type(est).__name__} requires y to be passed, "
                                 "but the target y is None")
            y = np.asarray(y)
            if not multi_output and y.ndim == 2 and y.shape[1] == 1:
                y = y.ravel()
            if y_numeric or y.dtype.kind in "biuf":
                y = np.ascontiguousarray(y, dtype=np.float64) if y_numeric else y
            if out and len(y) != out[0].shape[0]:
                raise ValueError("X and y have inconsistent numbers of samples")
            out.append(y)
        return out[0] if len(out) == 1 else tuple(out)


__all__ = ["BaseEstimator", "ClassifierMixin", "RegressorMixin", "TransformerMixin",
           "DensityMixin", "check_is_fitted", "HAVE_SKLEARN",
           "fit_xy", "fit_x", "pred_x", "classes_of", "Tagged"]


# The fast path.  scikit-learn's validate_data costs about 100 us a
# call whatever the size (feature names, array namespaces, the config),
# which is most of a small fit and nearly all of a small predict.  An
# input that is already what the kernels take -- a plain ndarray,
# float64, C-ordered, 2-D, non-empty, finite -- needs none of that
# machinery, so it is checked here directly; anything else (a list, a
# DataFrame, another dtype, NaN, a wrong feature count) goes through
# validate_data, which raises the error scikit-learn would.  Finiteness
# is tested by one sum, as scikit-learn tests it first, and skipped
# under sklearn.set_config(assume_finite=True).
if HAVE_SKLEARN:
    from sklearn import get_config as _get_config

    def _assume_finite():
        return _get_config()["assume_finite"]
else:
    def _assume_finite():
        return False


def _plain(X):
    return (type(X) is np.ndarray and X.dtype == np.float64 and X.ndim == 2
            and X.flags.c_contiguous and X.shape[0] > 0 and X.shape[1] > 0)


def _finite(a):
    if _assume_finite():
        return True
    with np.errstate(over="ignore", invalid="ignore"):
        return bool(np.isfinite(a.sum()))


def _labels_ok(y):
    # what check_classification_targets accepts, in the cheap cases:
    # integer or boolean labels, or floats that are all integral
    k = y.dtype.kind
    if k in "biu":
        return True
    if k == "f":
        with np.errstate(invalid="ignore"):
            return bool(np.isfinite(y.sum())) and bool((y == np.floor(y)).all())
    return False


def _reset_names(est):
    # what validate_data does on fit with an ndarray: no feature names
    if "feature_names_in_" in vars(est):
        del est.feature_names_in_


def fit_xy(est, X, y, *, y_numeric=True, multi_output=False, classifier=False):
    """X as a float64 C-ordered 2-D array and y, validated, n_features_in_ set."""
    if (_plain(X) and type(y) is np.ndarray and y.shape[0:1] == X.shape[0:1]
            and (y.ndim == 1 or (multi_output and y.ndim == 2 and y.shape[1] > 1))
            and _finite(X)):
        if classifier:
            ok = _labels_ok(y)
        elif y_numeric:
            ok = y.dtype == np.float64 and y.flags.c_contiguous and _finite(y)
        else:
            ok = y.dtype.kind in "biuf" and _finite(y)
        if ok:
            est.n_features_in_ = X.shape[1]
            _reset_names(est)
            return X, y
    X, y = _sk_validate(est, X, y, dtype=np.float64, order="C",
                        y_numeric=y_numeric and not classifier, multi_output=multi_output)
    if classifier:
        check_classification_targets(y)
    elif y_numeric:
        y = np.ascontiguousarray(y, dtype=np.float64)
    return X, y


def fit_x(est, X, ensure_min_samples=1, ensure_min_features=1):
    """X alone (unsupervised fit), validated, n_features_in_ set."""
    if (_plain(X) and X.shape[0] >= ensure_min_samples and X.shape[1] >= ensure_min_features
            and _finite(X)):
        est.n_features_in_ = X.shape[1]
        _reset_names(est)
        return X
    return _sk_validate(est, X, dtype=np.float64, order="C",
                        ensure_min_samples=ensure_min_samples,
                        ensure_min_features=ensure_min_features)


def pred_x(est, X, **kw):
    """X at predict / transform time: fitted, and as many features as at fit."""
    d = vars(est)
    if (not kw and _plain(X) and X.shape[1] == d.get("n_features_in_")
            and "feature_names_in_" not in d and _finite(X)):
        return X
    check_is_fitted(est)
    return _sk_validate(est, X, reset=False, dtype=np.float64, order="C", **kw)


def classes_of(y):
    """classes_ and the 0-based label index, as LabelEncoder has them."""
    return np.unique(np.asarray(y), return_inverse=True)


class Tagged:
    """Declares scikit-learn tags from a few class attributes.

    _binary_only: the solver is a two-class one (multi_class False).
    _positive_X / _positive_y: the input or target must be non-negative.
    _multi_output: y may be (n, k), and must be for _multi_output == "only".
    _no_y: an unsupervised fit (y ignored).
    """
    _binary_only = False
    _positive_X = False
    _positive_y = False
    _multi_output = False
    _pairwise = False

    def __sklearn_tags__(self):
        tags = super().__sklearn_tags__()
        tags.input_tags.positive_only = self._positive_X
        tags.input_tags.pairwise = bool(self._pairwise_now())
        if tags.target_tags is not None:
            tags.target_tags.positive_only = self._positive_y
            if self._multi_output:
                tags.target_tags.multi_output = True
                if self._multi_output == "only":
                    tags.target_tags.single_output = False
        if self._binary_only and tags.classifier_tags is not None:
            tags.classifier_tags.multi_class = False
        return tags

    def _more_tags(self):           # scikit-learn before 1.6
        t = {"binary_only": self._binary_only, "pairwise": bool(self._pairwise_now())}
        if self._positive_X:
            t["requires_positive_X"] = True
        if self._positive_y:
            t["requires_positive_y"] = True
        if self._multi_output:
            t["multioutput"] = True
            if self._multi_output == "only":
                t["multioutput_only"] = True
        return t

    def _pairwise_now(self):
        return self._pairwise and getattr(self, "kernel", None) == "precomputed"

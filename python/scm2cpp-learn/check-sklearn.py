"""scikit-learn's check_estimator over every estimator of the package.

    python check-sklearn.py              # all of them, one process each
    python check-sklearn.py GramLasso    # one, with each failing check shown

Each estimator runs in its own process, so a crash in one is reported
as that estimator's failure and the rest still run.  A check listed in
EXPECTED_FAILED is passed to check_estimator as expected to fail, with
its reason; the script fails when a check outside that list fails, or
when a listed check passes (the list is then stale).  Needs
scikit-learn 1.6 or later.
"""
import json
import subprocess
import sys

ESTIMATORS = [
    "GramLasso", "GramElasticNet", "GramRidge", "GramRidgeCV", "GramLogisticRegression", "GramGroupLasso",
    "GramMultiTaskLasso", "GramMultiTaskElasticNet", "DesignLasso",
    "CovLassoCV", "CovMultiTaskLassoCV",
    "CovBayesianRidge", "CovARDRegression", "LinearSVM", "KernelSVM", "LinearSVR",
    "KernelSVR", "L1LinearSVM", "L1LogisticRegression", "LBFGSLogisticRegression",
    "LBFGSLogisticRegressionCV", "LBFGSPoissonRegressor", "LBFGSGammaRegressor",
    "LBFGSTweedieRegressor", "LBFGSHuberRegressor", "SGDLinearClassifier",
    "SGDLinearRegressor", "SGDPerceptron", "GramOMP", "GramOMPCV", "GramLars",
    "GramLassoLars", "GramLarsCV", "GramLassoLarsCV", "GramLassoLarsIC",
    "WeiszfeldTheilSen", "LinearRANSAC", "GramRFE", "SelectKBest", "SelectPercentile",
    "CDNMF", "CovPCA", "GramKernelPCA", "GramLDA", "GramTruncatedSVD", "GramPLSRegression", "GramPLSCanonical", "GramCCA", "GramPLSSVD", "GramFactorAnalysis", "GramLinearRegression", "ParallelFastICA", "EMGaussianMixture", "CDGraphicalLasso",
]

# constructor arguments for the checks, as scikit-learn's own
# PER_ESTIMATOR_CHECK_PARAMS gives its PLS family (the checks pass one
# target, and the canonical modes take at most min(p, q) components)
CHECK_PARAMS = {name: dict(n_components=1, max_iter=5)
                for name in ("GramPLSRegression", "GramPLSCanonical", "GramCCA")}
CHECK_PARAMS["GramPLSSVD"] = dict(n_components=1)

# scikit-learn's checks treat its own cross-decomposition classes by name
# (CROSS_DECOMPOSITION): n_iter_ is a list, one entry per component, and
# fit_transform(X, y) returns the pair (x_scores, y_scores)
_PLS_BY_NAME = {
    "check_transformer_n_iter":
        "n_iter_ is one count per component, as PLSRegression's; scikit-learn "
        "accepts the list only for its own class names",
    "check_transformer_general":
        "fit_transform(X, y) returns (x_scores, y_scores), as _PLS's; scikit-learn "
        "compares the pair only for its own class names",
    "check_transformer_data_not_an_array":
        "fit_transform(X, y) returns (x_scores, y_scores), as _PLS's; scikit-learn "
        "compares the pair only for its own class names",
}

# check name -> why it is expected to fail, per estimator
EXPECTED_FAILED = {
    "LBFGSLogisticRegressionCV": {
        "check_non_transformer_estimators_n_iter":
            "a C warm-started from the previous one can start converged, 0 iterations; "
            "scikit-learn's LogisticRegressionCV reports the same 0s on this data",
    },
}


def run_one(name):
    import warnings
    from sklearn.utils.estimator_checks import check_estimator
    import scm2cpp_learn as m
    warnings.simplefilter("ignore")
    est = getattr(m, name)(**CHECK_PARAMS.get(name, {}))
    expected = dict(EXPECTED_FAILED.get(name, {}))
    if name in CHECK_PARAMS:
        expected.update({c: why for c, why in _PLS_BY_NAME.items()
                         if not (name == "GramPLSSVD" and c == "check_transformer_n_iter")})
    res = check_estimator(est, expected_failed_checks=expected, on_fail=None)
    out = []
    for r in res:
        st = r["status"]
        chk = r["check_name"]
        if st == "failed":
            exc = r.get("exception")
            out.append({"check": chk, "status": st,
                        "error": f"{type(exc).__name__}: {exc}"[:300] if exc else ""})
        elif chk in expected and st == "passed":
            out.append({"check": chk, "status": "unexpectedly passed", "error": ""})
    n_pass = sum(r["status"] == "passed" for r in res)
    n_xfail = sum(r["status"] == "xfail" for r in res)
    n_skip = sum(r["status"] == "skipped" for r in res)
    print(json.dumps({"name": name, "passed": n_pass, "xfail": n_xfail, "skipped": n_skip,
                      "problems": out}))


def main(argv):
    if len(argv) > 1 and argv[1] == "--one":
        run_one(argv[2])
        return 0
    names = argv[1:] or ESTIMATORS
    bad = 0
    for name in names:
        p = subprocess.run([sys.executable, __file__, "--one", name],
                           capture_output=True, text=True, timeout=1800)
        # the last JSON line (a BLAS library may print to stdout too)
        lines = [s for s in p.stdout.splitlines() if s.startswith("{")]
        line = lines[-1] if lines else ""
        try:
            r = json.loads(line)
        except ValueError:
            bad += 1
            print(f"{name:28s} CRASH rc={p.returncode} {p.stderr.strip()[-300:]}")
            continue
        status = "ok" if not r["problems"] else "FAIL"
        bad += status != "ok"
        print(f"{name:28s} {status:4s} passed={r['passed']} xfail={r['xfail']} "
              f"skipped={r['skipped']} failed={len(r['problems'])}")
        for q in r["problems"]:
            print(f"    {q['check']}: {q['status']} {q['error']}")
    print(f"---- estimators={len(names)} failing={bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

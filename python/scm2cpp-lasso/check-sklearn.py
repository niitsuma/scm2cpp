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
    "GramLasso", "GramElasticNet", "GramRidge", "GramLogisticRegression", "GramGroupLasso",
    "GramMultiTaskLasso", "GramMultiTaskElasticNet", "DesignLasso",
    "CovLassoCV", "CovMultiTaskLassoCV",
    "CovBayesianRidge", "CovARDRegression", "LinearSVM", "KernelSVM", "LinearSVR",
    "KernelSVR", "L1LinearSVM", "L1LogisticRegression", "LBFGSLogisticRegression",
    "LBFGSLogisticRegressionCV", "LBFGSPoissonRegressor", "LBFGSGammaRegressor",
    "LBFGSTweedieRegressor", "LBFGSHuberRegressor", "SGDLinearClassifier",
    "SGDLinearRegressor", "SGDPerceptron", "GramOMP", "GramOMPCV", "GramLars",
    "GramLassoLars", "GramLarsCV", "GramLassoLarsCV", "GramLassoLarsIC",
    "WeiszfeldTheilSen", "LinearRANSAC", "GramRFE", "SelectKBest", "SelectPercentile",
    "CDNMF", "CovPCA", "ParallelFastICA", "EMGaussianMixture", "CDGraphicalLasso",
]

# check name -> why it is expected to fail, per estimator
EXPECTED_FAILED = {
    "DesignLasso": {
        "check_non_transformer_estimators_n_iter":
            "the derived kernel does not report how many sweeps it ran",
    },
    "LBFGSLogisticRegressionCV": {
        "check_non_transformer_estimators_n_iter":
            "a C warm-started from the previous one can start converged, 0 iterations; "
            "scikit-learn's LogisticRegressionCV reports the same 0s on this data",
    },
}


def run_one(name):
    import warnings
    from sklearn.utils.estimator_checks import check_estimator
    import scm2cpp_lasso as m
    warnings.simplefilter("ignore")
    est = getattr(m, name)()
    expected = EXPECTED_FAILED.get(name, {})
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

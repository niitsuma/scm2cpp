"""darts' dynamic time warping with examples/kernel-only/dtw.scm inside.

    python3 bench/darts-dtw-compare.py --dir DIR [--quick]

DIR holds the -M build of examples/kernel-only/dtw.scm (dtw.py and
libdtw.so):

    cp examples/kernel-only/dtw.scm DIR/
    racket scm2cpp-file.scm -t scm2c.typ -M DIR/dtw.scm
    g++ -O3 -march=native -std=c++17 -fPIC -shared -I. \
        -o DIR/libdtw.so DIR/dtw_capi.cpp

darts (darts.dataprocessing.dtw, also behind darts.metrics.dtw_metric)
fills the cost matrix of the alignment one cell at a time in Python.
install() below puts the translated kernel in the place of the three
module functions that do the work,

  _dtw_cost_matrix   the cost matrix over a window,
  _dtw_path          the warp path read back from it,
  _expand_window     the window of the next finer grid (multi_grid_radius),

and leaves everything else of darts as it is: dtw(), DTWAlignment, the
windows, the metric.  A call the kernel does not cover (a distance
function of the caller's own, a window that is not a range per row,
series that are not float64, a value that is not finite) goes to darts'
own function.

What comes back is compared with darts' on every case:

  no window, or a window over half the grid or more: darts keeps the
    matrix in float64, and the kernel's is that matrix bit for bit;
  a narrower window (SakoeChiba, Itakura, the multi-grid solver): darts
    keeps the cells in an array of single-precision floats, the kernel
    in doubles.  The kernel's cells are compared bit for bit with darts'
    own loop run over an array of doubles, and the distance and the path
    with what darts returns as it is.

One core on both sides.
"""
import argparse
import array
import importlib
import importlib.util
import time
from itertools import repeat
from pathlib import Path

import numpy as np


def load(d, base):
    spec = importlib.util.spec_from_file_location("_scm2cpp_" + base, Path(d) / (base + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def install(kernel):
    """Put the kernel in darts' dtw module; returns the functions replaced
    (uninstall(saved) puts them back) and the counts of what was served."""
    D = importlib.import_module("darts.dataprocessing.dtw.dtw")
    cm = importlib.import_module("darts.dataprocessing.dtw.cost_matrix")
    win = importlib.import_module("darts.dataprocessing.dtw.window")
    saved = {name: getattr(D, name) for name in ("_dtw_cost_matrix", "_dtw_path", "_expand_window")}
    stats = {"cost": 0, "cost_darts": 0, "path": 0, "path_darts": 0, "expand": 0}
    inf = float("inf")

    class PackedCostMatrix(cm.SparseCostMatrix):
        """darts' SparseCostMatrix with its cells in doubles (darts: an
        array of single-precision floats), filled by the kernel."""

        def __init__(self, window):
            self.n = window.n
            self.m = window.m
            self.window = window
            self.column_ranges = window.column_ranges
            self.rng = np.frombuffer(window.column_ranges, dtype=np.intc)
            self.offsets = np.zeros(self.n + 2, dtype=np.intc)
            np.cumsum(np.maximum(self.rng[1::2] - self.rng[0::2], 0), out=self.offsets[1:])
            self.dense = np.empty(int(self.offsets[-1]))

    def ranges_of(window):
        """The window as the columns start .. end-1 of every row, or None."""
        if type(window) is win.NoWindow:
            rng = np.empty(2 * (window.n + 1), dtype=np.intc)
            rng[0::2] = 1
            rng[1::2] = window.m + 1
            rng[0], rng[1] = 0, 1
            return rng
        if isinstance(window, win.CRWindow):
            rng = np.frombuffer(window.column_ranges, dtype=np.intc)
            if rng.size == 2 * (window.n + 1) and rng[0] == 0 and rng[1] == 1 \
                    and (rng[2::2] >= 1).all() and (rng[3::2] <= window.m + 1).all():
                return rng
        return None

    def cost_matrix(x, y, dist, window):
        ok = (dist is D._default_distance_uni or dist is D._default_distance_multi)
        x = np.asarray(x)
        y = np.asarray(y)
        ok = ok and x.dtype == np.float64 and y.dtype == np.float64 and x.ndim == y.ndim \
            and x.ndim in (1, 2) and x.shape[1:] == y.shape[1:] and len(x) >= 1 and len(y) >= 1 \
            and len(x) == window.n and len(y) == window.m \
            and bool(np.isfinite(x).all()) and bool(np.isfinite(y).all())
        rng = ranges_of(window) if ok else None
        if rng is None:
            stats["cost_darts"] += 1
            return saved["_dtw_cost_matrix"](x, y, dist, window)
        n, m = window.n, window.m
        d = 1 if x.ndim == 1 else x.shape[1]
        stats["cost"] += 1
        # the storage darts' CostMatrix._from_window chooses
        if isinstance(window, win.CRWindow) and len(window) / ((n + 1) * (m + 1)) < 0.5:
            out = PackedCostMatrix(window)
            kernel.dtw_cost_packed(x, y, rng, out.offsets, out.dense, n, m, d, inf)
        else:
            out = cm.DenseCostMatrix(n, m)
            kernel.dtw_cost(x, y, rng, out, n, m, d, inf)
        return out

    def path(dtw):
        n, m = dtw.n, dtw.m
        buf = np.empty(2 * (n + m) + 2, dtype=np.intc)
        if isinstance(dtw, PackedCostMatrix) and n + m > 0:
            k = kernel.dtw_path_packed(dtw.dense, dtw.rng, dtw.offsets, buf, n, m, inf)
        elif (type(dtw) is cm.DenseCostMatrix and dtw.dtype == np.float64 and dtw.flags.c_contiguous
              and dtw.shape == (n + 1, m + 1) and n + m > 0):
            k = kernel.dtw_path(dtw, buf, n, m)
        else:
            stats["path_darts"] += 1
            return saved["_dtw_path"](dtw)
        stats["path"] += 1
        return buf[:2 * k].reshape(k, 2)[::-1].astype(np.int64)

    def expand_window(low_res_path, n, m, radius):
        low = np.ascontiguousarray(low_res_path, dtype=np.intc)
        if low.ndim != 2 or low.shape[1] != 2 or radius < 0 or (low < 0).any():
            return saved["_expand_window"](low_res_path, n, m, radius)
        rng = np.empty(2 * (n + 1), dtype=np.intc)
        cells = kernel.dtw_expand_window(low, len(low), rng, n, m, radius)
        stats["expand"] += 1
        window = win.CRWindow(n, m)
        window.column_ranges = array.array("i", rng.tobytes())
        window.length = int(cells)
        return window

    D._dtw_cost_matrix = cost_matrix
    D._dtw_path = path
    D._expand_window = expand_window
    return saved, stats


def uninstall(saved):
    D = importlib.import_module("darts.dataprocessing.dtw.dtw")
    for name, f in saved.items():
        setattr(D, name, f)


class doubles_in_sparse:
    """While active, darts' SparseCostMatrix keeps doubles (array "d")
    in place of single-precision floats: the reference the kernel's
    packed matrix is compared with bit for bit."""

    def __enter__(self):
        cm = importlib.import_module("darts.dataprocessing.dtw.cost_matrix")
        self.cm, self.init = cm, cm.SparseCostMatrix.__init__
        init = self.init

        def init_d(self_, window):
            init(self_, window)
            self_.dense = array.array("d", repeat(np.inf, len(self_.dense)))

        cm.SparseCostMatrix.__init__ = init_d

    def __exit__(self, *exc):
        self.cm.SparseCostMatrix.__init__ = self.init


def series(n, d, seed):
    from darts import TimeSeries
    rng = np.random.default_rng(seed)
    t = np.arange(n)
    v = np.stack([np.sin(2 * np.pi * t / (40.0 + 7 * k) + rng.uniform(0, 3))
                  + 0.3 * np.cumsum(rng.standard_normal(n)) / np.sqrt(n)
                  + 0.1 * rng.standard_normal(n) for k in range(d)], axis=1)
    return TimeSeries.from_values(v)


def timed(fn):
    t = time.perf_counter()
    out = fn()
    return out, time.perf_counter() - t


def cells_of(cost):
    """The window's cells as one array of doubles (the whole matrix for a dense one)."""
    return np.asarray(cost.dense, dtype=np.float64) if hasattr(cost, "dense") else np.asarray(cost)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--quick", action="store_true", help="small sizes only (a check, not a timing)")
    args = ap.parse_args()
    import logging
    import darts
    from darts.dataprocessing.dtw import dtw, SakoeChiba, Itakura
    from darts.metrics import dtw_metric
    logging.getLogger("darts").setLevel(logging.ERROR)
    kernel = load(args.dir, "dtw")
    q = args.quick
    cases = [
        ("no window, 1 component", (300, 280) if q else (1500, 1400), 1, dict()),
        ("no window, 3 components", (200, 220) if q else (800, 900), 3, dict()),
        ("SakoeChiba(100)", (600, 600) if q else (6000, 6000), 1, dict(window=SakoeChiba(100))),
        ("SakoeChiba(20), 2 components", (500, 510) if q else (4000, 4010), 2, dict(window=SakoeChiba(20))),
        ("Itakura(2)", (300, 300) if q else (1500, 1500), 1, dict(window=Itakura(2))),
        ("multi_grid_radius=10", (1000, 900) if q else (20000, 19000), 1, dict(multi_grid_radius=10)),
        ("multi_grid_radius=0", (700, 700) if q else (20000, 20000), 1, dict(multi_grid_radius=0)),
    ]
    print("darts %s, dtw(): seconds for the alignment, its distance and its path" % darts.__version__)
    print("%-30s %13s %9s %9s %7s  %s" % ("case", "n x m", "darts", "kernel", "ratio", "against darts"))
    bad = 0
    for name, (n, m), d, kw in cases:
        a, b = series(n, d, 1), series(m, d, 2)

        def run():
            al = dtw(a, b, **kw)
            return al, al.distance(), al.path()

        (al0, dist0, path0), t0 = timed(run)
        with doubles_in_sparse():
            ref = dtw(a, b, **kw)
            ref_path = ref.path()
        saved, stats = install(kernel)
        try:
            (al1, dist1, path1), t1 = timed(run)
        finally:
            uninstall(saved)
        same_cells = np.array_equal(cells_of(ref.cost), cells_of(al1.cost))
        same_ref_path = np.array_equal(ref_path, path1) and path1.dtype == ref_path.dtype
        packed = hasattr(al1.cost, "dense")
        if not (same_cells and same_ref_path and stats["cost"] >= 1 and stats["cost_darts"] == 0
                and stats["path_darts"] == 0):
            bad += 1
        if packed:
            note = "cells %s (darts in doubles), distance off by %.1e (darts in single), path %s" % (
                "identical" if same_cells else "DIFFERENT",
                abs(float(dist1) - float(dist0)) / max(abs(float(dist0)), 1e-300),
                "identical" if np.array_equal(path0, path1) else
                "%d of %d steps differ" % (int((path0 != path1).any(axis=1).sum()) if path0.shape == path1.shape
                                           else abs(len(path0) - len(path1)), len(path0)))
        else:
            if not (np.array_equal(cells_of(al0.cost), cells_of(al1.cost)) and np.array_equal(path0, path1)
                    and float(dist0) == float(dist1)):
                bad += 1
            note = "cells %s, path %s" % ("identical" if same_cells else "DIFFERENT",
                                          "identical" if np.array_equal(path0, path1) else "DIFFERENT")
        print("%-30s %13s %9.3f %9.4f %6.0fx  %s" % (name, "%d x %d" % (n, m), t0, t1, t0 / t1, note))

    # the metric: the alignment, the two series warped along it, their mean absolute error
    n = 300 if q else 1500
    a, b = series(n, 1, 3), series(n, 1, 4)
    v0, t0 = timed(lambda: dtw_metric(a, b))
    saved, stats = install(kernel)
    try:
        v1, t1 = timed(lambda: dtw_metric(a, b))
    finally:
        uninstall(saved)
    if not (float(v0) == float(v1) and stats["cost"] == 1):
        bad += 1
    print("%-30s %13s %9.3f %9.4f %6.0fx  %s" % ("dtw_metric (no window)", "%d x %d" % (n, n), t0, t1, t0 / t1,
                                                "value identical" if float(v0) == float(v1) else "value DIFFERENT"))

    # what the kernel does not cover goes to darts' own loop
    a, b = series(60, 1, 5), series(50, 1, 6)
    sq = lambda u, v: (u - v) ** 2          # noqa: E731
    r0 = dtw(a, b, distance=sq)
    saved, stats = install(kernel)
    try:
        r1 = dtw(a, b, distance=sq)
        d1, p1 = r1.distance(), r1.path()
    finally:
        uninstall(saved)
    if not (stats["cost"] == 0 and stats["cost_darts"] == 1 and float(r0.distance()) == float(d1)
            and np.array_equal(r0.path(), p1)):
        bad += 1
    print("a distance function of the caller's own: darts' loop, distance and path %s"
          % ("identical" if float(r0.distance()) == float(d1) and np.array_equal(r0.path(), p1) else "DIFFERENT"))
    print("ALL SAME" if bad == 0 else "%d DIFFERENT" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())

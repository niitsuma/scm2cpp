"""Run a notebook top to bottom in a fresh kernel, as Colab's "Run all"
does, and fail on the first cell that raises.

    python tools/run-notebook.py notebooks/compare-sklearn.ipynb

The suite never runs the notebook, so a cell that breaks only on
another machine (Colab's CPU runtime has no nvidia-smi at all) goes
unseen; wheels.yml runs this on its Linux wheel, on a runner with no
GPU.  Needs nbclient and ipykernel.  Install the package first: the
notebook's own `pip install scm2cpp-learn` then finds it installed and
leaves it, so the copy under test is the one installed, not PyPI's.
"""
import sys
import time

import nbformat
from nbclient import NotebookClient
from nbclient.exceptions import CellExecutionError

path = sys.argv[1]
nb = nbformat.read(path, as_version=4)
t0 = time.perf_counter()
try:
    NotebookClient(nb, timeout=1800, kernel_name="python3").execute()
except CellExecutionError as e:
    print(f"run-notebook: {path} failed:\n{e}", file=sys.stderr)
    sys.exit(1)
cells = sum(c.cell_type == "code" for c in nb.cells)
print(f"run-notebook: {path}: {cells} code cells ran ({time.perf_counter() - t0:.0f} s)")

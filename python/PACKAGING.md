# From a Scheme kernel to `pip install`

*[Japanese (PACKAGING.ja.md)](PACKAGING.ja.md)*

How a numerical routine written in the scm2cpp subset becomes a Python
package that installs with a C++ compiler and no Racket.  The two
packages here (`scm2cpp-lasso/`, `scm2cpp-tfs/`) are built this way;
copy their layout rather than starting from nothing.

## 1. Write the kernel so that `-M` can expose it

`-M` emits `extern "C"` wrappers and a ctypes loader for every
function whose types resolved concretely.  Write the kernel as such
functions:

- No `main`.  One function per entry point, its result left in an
  out-parameter, returning `0`.  (The function's own return value does
  cross, but a scalar; a vector result does not.)
- Arrays are flat `double` vectors indexed by hand: `x[j*n+i]` for a
  column-major design, `(vector-ref x (+ (* j n) i))`.  A parameter
  nothing constrains to floating point is multiplied by `(* 1.0 n)`
  once so that it does not become `int`.
- Sizes are parameters (`n`, `p`), never vector literals: a
  `(make-vector 10 0.0)` of fixed size becomes `std::array` and the
  wrapper cannot take an arbitrary numpy array for it.
- A function the translator leaves with a template parameter
  (`Unknown_typeNNNType`) is skipped by `-M` with a named comment;
  give it a call site or a `(* 1.0 ..)` so that its types close.
- Shared definitions come in by `(include "file.scm")`
  (`soft-threshold.scm` is one), not by copying.
- If the kernel should go through `--derive`, declare its shapes with
  `(with-arrays ((x (p n)) (resid (n)) ..) ..)` at the head of the
  body, as `examples/kernel-only/lasso-kernel.scm` does; the
  declaration changes nothing in the plain translation.

Try it before packaging (`examples/kernel-only/README.md` has the
full example):

```console
$ racket scm2cpp-file.scm -t scm2c.typ -M kernel.scm      # kernel.hpp .cpp _capi.cpp .py
$ g++ -O2 -std=c++17 -shared -fPIC -I. -o libkernel.so kernel_capi.cpp
$ python3 -c 'import kernel; kernel.my_entry(x, out, n, p)'  # kernel.py loads libkernel.so beside it
```

The generated `kernel.py` makes every array contiguous `float64` on
the way in and mutates it in place, so pass preallocated contiguous
arrays for the outputs.

## 2. The package layout

Take `scm2cpp-lasso/` as the template; the parts are:

| file | what it does |
|------|--------------|
| `regenerate.sh` | Translates the Scheme into `src/<pkg>/_generated/` (`-M`, plus `--derive`/`--blas` if wanted), copies `scm2cpp.hpp` (and `scm2cpp-blas.hpp`) beside it, and rewrites the loader's `ctypes.CDLL(...)` line to go through `_libfind`.  The only step that needs Racket; its output is committed. |
| `src/<pkg>/_generated/` | The translator's output, committed, so that `pip` needs a C++17 compiler and nothing else. |
| `src/<pkg>/_libfind.py` | Finds the built extension by its stem whatever ABI tag the interpreter gave it, and reports which optional variants were built. |
| `setup.py` | One `Extension` per `_capi.cpp`, `include_dirs=[_generated]`; optional pieces (a CUDA library through `nvcc`, a BLAS variant through a compile-and-link probe) are tried and skipped, never required. |
| `pyproject.toml` | Metadata, `numpy` as the dependency, and `package-data` listing `_generated/**/*.hpp` and `*.cpp` so that sdists carry them. |
| `src/<pkg>/__init__.py` | The classes users call: validate shapes, lay the arrays out as the kernel wants them (`np.ascontiguousarray(X.T)` for a column-major design), preallocate the outputs, call the loader's function, reshape the result. |
| `check-*.py` | A script that runs the package against a reference (numpy, scikit-learn, or the package's own other route) on random data and prints the differences; run in the venv after every reinstall. |

Reinstall after any change under `src/` (`pip install .`, not `-e`):
the C++ is compiled at install time and the loader binds entry points
by name, so a stale library shows up as a missing symbol, not an error.

## 3. If the kernel lives in this repository

- Put the Scheme under `examples/kernel-only/`, add a row to
  `FILES.md` / `FILES.ja.md`, and have `regenerate.sh` copy it from
  there.
- Add a case to `run-tests.sh` that translates it with `-M`, builds
  the `.so` and runs a small Python comparison (`pymodule-lasso` and
  `pymodule-derived` are the two to copy), so that the suite catches a
  signature change before the package does.
- A numbered section in `CHANGES.ja.md`, and the version bumped in
  `pyproject.toml` and `__init__.py` together.

## 4. Publish

```console
$ cd python/<pkg> && python3 -m build        # sdist + wheel from the committed C++
$ python3 -m twine upload dist/*             # with your PyPI token
```

The sdist is what most users will build from, since the wheel is
specific to the interpreter and machine it was built on.

"""Build the translated kernel, and the CUDA path when nvcc is here.

The C++ this compiles is committed, not generated at install time, so
building the package needs a C++17 compiler and nothing else -- no
Racket, no scm2cpp.  A CBLAS (cblas.h plus openblas) at install time
gives the derived kernel its BLAS variant; without one the loop
variant is built.  regenerate.sh is how the committed sources are
refreshed, and it is the only thing that needs the translator.

The CUDA library is optional in the strongest sense: no nvcc, no
device, or a failed nvcc all leave a working CPU package behind, and
the batch path notices at import and falls back.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext

HERE = Path(__file__).resolve().parent
# setuptools wants sources and include paths relative to this file and
# separated by forward slashes, on every platform
PKG_REL = "src/scm2cpp_lasso"
GEN_REL = PKG_REL + "/_generated"
PKG = HERE / "src" / "scm2cpp_lasso"
GEN = PKG / "_generated"

# MSVC: /EHsc for C++ exceptions, /bigobj for the large generated files
MSVC = ["/O2", "/std:c++17", "/EHsc", "/bigobj"]
CXXFLAGS = ["-O2", "-std=c++17"] if os.name != "nt" else MSVC

kernel = Extension(
    "scm2cpp_lasso._lasso_cov",
    sources=[GEN_REL + "/lasso_cov_capi.cpp"],
    include_dirs=[GEN_REL],
    extra_compile_args=CXXFLAGS,
)


def cblas_flags():
    """How to compile and link against a CBLAS here, or None.

    pkg-config for openblas where it answers, else the bare -lopenblas
    if a test program compiles and links against it.  The derived
    kernel's BLAS variant needs cblas.h and a library; without them the
    loop variant is built instead (same answers, the Gram as a scalar
    loop nest).

    On Windows there is no pkg-config and no system OpenBLAS: the
    directory of an unpacked OpenBLAS release (include/cblas.h,
    lib/libopenblas.lib) is named by SCM2CPP_OPENBLAS_DIR, and the
    wheel build bundles its bin/libopenblas.dll (delvewheel).
    """
    if os.environ.get("SCM2CPP_NO_BLAS"):
        return None
    if os.name == "nt":
        root = os.environ.get("SCM2CPP_OPENBLAS_DIR")
        if not root:
            return None
        inc, lib = Path(root) / "include", Path(root) / "lib" / "libopenblas.lib"
        if not ((inc / "cblas.h").exists() and lib.exists()):
            return None
        return ["-I" + str(inc), str(lib)]
    cxx = os.environ.get("CXX", "c++")
    candidates = []
    try:
        pc = subprocess.run(["pkg-config", "--cflags", "--libs", "openblas"],
                            capture_output=True, text=True, check=True)
        candidates.append(pc.stdout.split())
    except (subprocess.CalledProcessError, OSError):
        pass
    candidates.append(["-lopenblas"])
    probe = "#include <cblas.h>\nint main(){double a=1,b=0;" \
            "cblas_dgemv(CblasRowMajor,CblasNoTrans,1,1,1.0,&a,1,&a,1,0.0,&b,1);" \
            "return b==1?0:1;}\n"
    for flags in candidates:
        try:
            r = subprocess.run([cxx, "-x", "c++", "-", "-o", os.devnull] + flags,
                               input=probe, capture_output=True, text=True)
        except OSError:
            return None
        if r.returncode == 0:
            return flags
    return None


def openmp_flags():
    """-fopenmp where the compiler takes the directives the translator
    writes (-P omp: parallel for, reduction, an if clause on the work),
    else nothing -- the same sources then compile serial.  Not on
    Windows (MSVC's OpenMP needs vcomp140.dll beside the wheel) nor
    with SCM2CPP_NO_OPENMP set.  OMP_NUM_THREADS sets the threads at
    run time, all cores by default.
    """
    if os.name == "nt" or os.environ.get("SCM2CPP_NO_OPENMP"):
        return []
    cxx = os.environ.get("CXX", "c++")
    probe = "int main(){double s=0;int n=4;\n" \
            "#pragma omp parallel for reduction(+:s) if(n > 1)\n" \
            "for(int i = 0 ; i < n ; i = (i+1)) s = (s+i);\n" \
            "return s==6?0:1;}\n"
    try:
        r = subprocess.run([cxx, "-fopenmp", "-x", "c++", "-", "-o", os.devnull],
                           input=probe, capture_output=True, text=True)
    except OSError:
        return []
    return ["-fopenmp"] if r.returncode == 0 else []


_omp = openmp_flags()


# The derived kernel: lasso-design.scm, the plain residual-form
# coordinate descent over X as numpy holds it, turned into the Gram form by the translator
# (--derive) with its products as CBLAS calls (--blas).  Which variant
# is built is visible in the extension's name; _libfind reports it.
_blas = cblas_flags()
if _blas is not None:
    derived = Extension(
        "scm2cpp_lasso._lasso_derived_blas",
        sources=[GEN_REL + "/derived_blas/lasso_design_capi.cpp"],
        include_dirs=[GEN_REL + "/derived_blas", GEN_REL],
        extra_compile_args=CXXFLAGS + [f for f in _blas if f.startswith("-I")
                                       or f.startswith("-D")],
        extra_link_args=[f for f in _blas if not f.startswith("-I")
                         and not f.startswith("-D")],
    )
else:
    derived = Extension(
        "scm2cpp_lasso._lasso_derived_loops",
        sources=[GEN_REL + "/derived_loops/lasso_design_capi.cpp"],
        include_dirs=[GEN_REL + "/derived_loops", GEN_REL],
        extra_compile_args=(["-O3", "-std=c++17"] if os.name != "nt" else MSVC),
    )


class BuildWithCuda(build_ext):
    def get_export_symbols(self, ext):
        # The extensions are plain shared libraries the package loads
        # through ctypes, not Python modules: no PyInit_ entry point,
        # and on Windows a DLL shows ctypes only what it exports, so the
        # exports are the extern "C" wrappers of the -M C API.  (Unix
        # linkers export everything and ignore this list.)
        names = []
        for src in ext.sources:
            if src.endswith("_capi.cpp"):
                text = (HERE / src).read_text()
                names += re.findall(r'extern "C"[^(\n]*?\b(scm2cpp_\w+)\(', text)
        return names

    def build_extensions(self):
        # the kernel is C++ compiled through the usual machinery, so
        # wheels and cross-compilation behave as they always do
        super().build_extensions()
        if os.environ.get("SCM2CPP_NO_CUDA"):
            return
        nvcc = shutil.which("nvcc")
        if not nvcc:
            return
        out = Path(self.build_lib) / "scm2cpp_lasso" / "libscm2cpp_batch.so"
        out.parent.mkdir(parents=True, exist_ok=True)
        cmd = [nvcc, "-O2", "-std=c++17", "-shared",
               "-Xcompiler", "-fPIC",
               "-I", str(PKG), "-I", str(GEN),
               str(PKG / "batch_capi.cu"), "-o", str(out),
               "-Wno-deprecated-gpu-targets", "-diag-suppress", "174"]
        try:
            subprocess.run(cmd, check=True)
            print("scm2cpp_lasso: built the CUDA batch path")
        except (subprocess.CalledProcessError, OSError) as exc:
            print(f"scm2cpp_lasso: no CUDA batch path ({exc}); "
                  "the CPU solver is unaffected", file=sys.stderr)
        # the --cuda translation (kernels + device-resident cuBLAS):
        # FastICA, the mixture, the L-BFGS fits
        gpu = GEN / "gpu_cuda" / "gpu_capi.cpp"
        if gpu.exists():
            out2 = Path(self.build_lib) / "scm2cpp_lasso" / "libscm2cpp_gpu.so"
            # the installed device's architecture when one answers
            arch = []
            try:
                if subprocess.run(["nvidia-smi"], capture_output=True).returncode == 0:
                    arch = ["-arch=native"]
            except OSError:
                pass
            cmd2 = [nvcc, "-O3", "-std=c++17", "-shared", "-x", "cu", *arch,
                    "-Xcompiler", "-fPIC", "-I", str(GEN / "gpu_cuda"), "-I", str(GEN),
                    str(gpu), "-o", str(out2), "-lcublas",
                    "-Wno-deprecated-gpu-targets", "-diag-suppress", "174,177,550"]
            try:
                subprocess.run(cmd2, check=True)
                print("scm2cpp_lasso: built the --cuda estimators")
            except (subprocess.CalledProcessError, OSError) as exc:
                print(f"scm2cpp_lasso: no --cuda estimators ({exc}); "
                      "the CPU paths are unaffected", file=sys.stderr)


# The cuBLAS variant of the derived kernel: host C++ against the CUDA
# runtime and cuBLAS, so it builds wherever the toolkit's headers and
# libraries are, device or not; DerivedLasso uses it only when a device
# answers.  Skipped silently without the toolkit.
def cuda_home():
    if os.environ.get("SCM2CPP_NO_CUDA"):
        return None
    nvcc = shutil.which("nvcc")
    if not nvcc:
        return None
    home = Path(nvcc).resolve().parent.parent
    return home if (home / "include" / "cublas_v2.h").exists() else None


# The classifiers: three solvers scikit-learn runs (liblinear's linear
# SVM and L1 logistic regression, libsvm's SMO), translated plainly.
# -O3 so the dense loops vectorise, which is where their speed is, and
# -fstrict-overflow to undo the -fno-strict-overflow Python's build
# flags carry: with signed overflow defined the compiler cannot treat
# the flat index i*p + j as an induction variable, and the linear SVM's
# sweep runs 25% slower.
_cls_flags = ["-O3", "-std=c++17", "-fstrict-overflow"] if os.name != "nt" else MSVC
classifiers = Extension(
    "scm2cpp_lasso._classifiers",
    sources=[GEN_REL + "/classifiers_capi.cpp"],
    include_dirs=[GEN_REL],
    extra_compile_args=_cls_flags + _omp,
    extra_link_args=_omp,
)

# The derived NMF, in the same variants as the derived lasso.
if _blas is not None:
    nmf = Extension(
        "scm2cpp_lasso._nmf_blas",
        sources=[GEN_REL + "/nmf_blas/nmf_cd_capi.cpp"],
        include_dirs=[GEN_REL + "/nmf_blas", GEN_REL],
        extra_compile_args=_cls_flags
        + [f for f in _blas if f.startswith("-I") or f.startswith("-D")],
        extra_link_args=[f for f in _blas if not f.startswith("-I")
                         and not f.startswith("-D")],
    )
else:
    nmf = Extension(
        "scm2cpp_lasso._nmf_loops",
        sources=[GEN_REL + "/nmf_loops/nmf_cd_capi.cpp"],
        include_dirs=[GEN_REL + "/nmf_loops", GEN_REL],
        extra_compile_args=_cls_flags,
    )

# The solvers with BLAS products (graphical lasso, OMP, L-BFGS for the
# logistic and Huber objectives): dgemm / dgemv / dsyrk where a CBLAS
# links, loops otherwise.
if _blas is not None:
    gramops = Extension(
        "scm2cpp_lasso._gramops_blas",
        sources=[GEN_REL + "/gramops_blas/gramops_capi.cpp"],
        include_dirs=[GEN_REL + "/gramops_blas", GEN_REL],
        extra_compile_args=_cls_flags + _omp
        + [f for f in _blas if f.startswith("-I") or f.startswith("-D")],
        extra_link_args=_omp + [f for f in _blas if not f.startswith("-I")
                                and not f.startswith("-D")],
    )
else:
    gramops = Extension(
        "scm2cpp_lasso._gramops_loops",
        sources=[GEN_REL + "/gramops_loops/gramops_capi.cpp"],
        include_dirs=[GEN_REL + "/gramops_loops", GEN_REL],
        extra_compile_args=_cls_flags + _omp,
        extra_link_args=_omp,
    )

_cuda = cuda_home()
extensions = [kernel, derived, classifiers, nmf, gramops]
if _cuda is not None:
    extensions.append(Extension(
        "scm2cpp_lasso._lasso_derived_cublas",
        sources=[GEN_REL + "/derived_cublas/lasso_design_capi.cpp"],
        include_dirs=[GEN_REL + "/derived_cublas", GEN_REL, str(_cuda / "include")],
        library_dirs=[str(_cuda / "lib64"), str(_cuda / "lib")],
        libraries=["cublas", "cudart"],
        extra_compile_args=CXXFLAGS,
    ))
    extensions.append(Extension(
        "scm2cpp_lasso._nmf_cublas",
        sources=[GEN_REL + "/nmf_cublas/nmf_cd_capi.cpp"],
        include_dirs=[GEN_REL + "/nmf_cublas", GEN_REL, str(_cuda / "include")],
        library_dirs=[str(_cuda / "lib64"), str(_cuda / "lib")],
        libraries=["cublas", "cudart"],
        extra_compile_args=_cls_flags,
    ))

    extensions.append(Extension(
        "scm2cpp_lasso._accel_cublas",
        sources=[GEN_REL + "/accel_cublas/accel_capi.cpp"],
        include_dirs=[GEN_REL + "/accel_cublas", GEN_REL, str(_cuda / "include")],
        library_dirs=[str(_cuda / "lib64"), str(_cuda / "lib")],
        libraries=["cublas", "cudart"],
        extra_compile_args=_cls_flags,
    ))

# A wheel is tagged py3-none-<platform>: the extensions are shared
# libraries the package loads through ctypes, using no Python API, so
# one build serves every Python on that platform.
try:
    from setuptools.command.bdist_wheel import bdist_wheel
except ImportError:  # setuptools before 70.1
    try:
        from wheel.bdist_wheel import bdist_wheel
    except ImportError:
        bdist_wheel = None

cmdclass = {"build_ext": BuildWithCuda}
if bdist_wheel is not None:
    class PlatformWheel(bdist_wheel):
        def finalize_options(self):
            super().finalize_options()
            self.root_is_pure = False

        def get_tag(self):
            return ("py3", "none", super().get_tag()[2])

    cmdclass["bdist_wheel"] = PlatformWheel

setup(ext_modules=extensions, cmdclass=cmdclass)

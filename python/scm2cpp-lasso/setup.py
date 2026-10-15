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

CXXFLAGS = ["-O2", "-std=c++17"] if os.name != "nt" else ["/O2", "/std:c++17"]

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
    """
    if os.name == "nt" or os.environ.get("SCM2CPP_NO_BLAS"):
        return None
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
        extra_compile_args=(["-O3", "-std=c++17"] if os.name != "nt"
                            else ["/O2", "/std:c++17"]),
    )


class BuildWithCuda(build_ext):
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
_cls_flags = ["-O3", "-std=c++17", "-fstrict-overflow"] if os.name != "nt" else ["/O2", "/std:c++17"]
classifiers = Extension(
    "scm2cpp_lasso._classifiers",
    sources=[GEN_REL + "/classifiers_capi.cpp"],
    include_dirs=[GEN_REL],
    extra_compile_args=_cls_flags,
)

# The derived NMF, in the same variants as the derived lasso.
if _blas is not None:
    nmf = Extension(
        "scm2cpp_lasso._nmf_blas",
        sources=[GEN_REL + "/nmf_blas/nmf_cd_capi.cpp"],
        include_dirs=[GEN_REL + "/nmf_blas", GEN_REL],
        extra_compile_args=CXXFLAGS + ["-O3", "-fstrict-overflow"]
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
        extra_compile_args=CXXFLAGS + ["-O3", "-fstrict-overflow"]
        + [f for f in _blas if f.startswith("-I") or f.startswith("-D")],
        extra_link_args=[f for f in _blas if not f.startswith("-I")
                         and not f.startswith("-D")],
    )
else:
    gramops = Extension(
        "scm2cpp_lasso._gramops_loops",
        sources=[GEN_REL + "/gramops_loops/gramops_capi.cpp"],
        include_dirs=[GEN_REL + "/gramops_loops", GEN_REL],
        extra_compile_args=_cls_flags,
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
        extra_compile_args=CXXFLAGS + ["-O3", "-fstrict-overflow"],
    ))

setup(ext_modules=extensions, cmdclass={"build_ext": BuildWithCuda})

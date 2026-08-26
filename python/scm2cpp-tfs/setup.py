"""Build the translated kernels, and the CUDA path when nvcc is here.

The C++ this compiles is committed, not generated at install time, so
building the package needs a C++17 compiler and nothing else -- no
Racket, no scm2cpp.  regenerate.sh is how the committed sources are
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
PKG_REL = "src/scm2cpp_tfs"
GEN_REL = PKG_REL + "/_generated"
PKG = HERE / "src" / "scm2cpp_tfs"
GEN = PKG / "_generated"

kernel = Extension(
    "scm2cpp_tfs._tfs_kernel",
    sources=[GEN_REL + "/lasso_cov_capi.cpp",
             GEN_REL + "/tfs_predict_capi.cpp",
             GEN_REL + "/autocov_capi.cpp",
             GEN_REL + "/levinson_capi.cpp"],
    include_dirs=[GEN_REL],
    extra_compile_args=(["-O2", "-std=c++17"] if os.name != "nt"
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
        out = Path(self.build_lib) / "scm2cpp_tfs" / "libscm2cpp_batch.so"
        out.parent.mkdir(parents=True, exist_ok=True)
        cmd = [nvcc, "-O2", "-std=c++17", "-shared",
               "-Xcompiler", "-fPIC",
               "-I", str(PKG), "-I", str(GEN),
               str(PKG / "batch_capi.cu"), "-o", str(out),
               "-Wno-deprecated-gpu-targets", "-diag-suppress", "174"]
        try:
            subprocess.run(cmd, check=True)
            print("scm2cpp_tfs: built the CUDA batch path")
        except (subprocess.CalledProcessError, OSError) as exc:
            print(f"scm2cpp_tfs: no CUDA batch path ({exc}); "
                  "the CPU solver is unaffected", file=sys.stderr)


setup(ext_modules=[kernel], cmdclass={"build_ext": BuildWithCuda})

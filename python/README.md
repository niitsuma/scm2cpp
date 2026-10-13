# Python packages

*[Japanese (README.ja.md)](README.ja.md)*

One directory per distribution, each installable on its own with pip.
They ship C++ that scm2cpp generated -- committed, not generated at
install time, so installing needs a compiler and not Racket -- and each
carries a `regenerate.sh` that refreshes those sources from the Scheme
in this repository.  That script is the only thing that needs the
translator.  `PACKAGING.md` is the procedure for packaging a kernel of
your own the same way.

| directory        | package         | what it is                                              |
|------------------|-----------------|---------------------------------------------------------|
| `scm2cpp-lasso/` | `scm2cpp-lasso` | lasso over a Gram matrix, for any design; optional CUDA batch path; `DerivedLasso`, the plain coordinate descent as the translator derived it |
| `scm2cpp-tfs/`   | `scm2cpp-tfs`   | moving-average feature selection: Gram matrix, descent and prediction, none of them forming the design |

The two overlap on purpose.  `scm2cpp-tfs` carries its own copy of the
descent rather than depending on `scm2cpp-lasso`, so either installs
alone; what distinguishes them is what they know.  The lasso package
knows nothing about where a Gram matrix came from, and the TFS package
knows that its design is moving averages of one series -- which is what
lets it build the Gram matrix, and predict, without the design.

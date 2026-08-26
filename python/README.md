# Python packages

One directory per distribution, each installable on its own with pip
and each shipping C++ that scm2cpp generated -- committed, not
generated at install time, so installing needs a compiler and not
Racket.  Every package carries a `regenerate.sh` that refreshes its
generated sources from the Scheme in this repository; that script is
the only thing that needs the translator.

| directory        | package         | what it solves                          |
|------------------|-----------------|-----------------------------------------|
| `scm2cpp-lasso/` | `scm2cpp-lasso` | lasso over moving-average features, with an optional CUDA batch path |

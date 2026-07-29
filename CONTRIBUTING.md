# Contributing to Scm2Cpp

## Reporting problems

Please open an issue on the repository. A useful report contains the Scheme
input, the command line used, the generated `.hpp` and `.cpp`, and the compiler
error or wrong output.

Translation failures fall into three kinds, and saying which one you hit helps:

1. the translator raises an exception,
2. the translator finishes but the generated C++ does not compile,
3. the generated C++ compiles but produces a wrong result.

For the first kind, running with `racket -l errortrace -u scm2cpp-file.scm ...`
gives the failing line inside the translator.

## Contributing code

1. Add a test program under `test-scm-code/` or `bench/` and list it in
   `run-tests.sh`.
2. Run `./run-tests.sh` before and after your change and include both tallies
   in the pull request. The suite translates each program, compiles the result
   and runs it.
3. Record the change and the reason for it in `CHANGES.ja.md`.

Changes to code generation should say which construct they affect and what the
generated C++ looked like before and after. The readability of the output is a
design goal, not a side effect, so a change that makes the output faster but
less readable needs to argue the trade-off.

## Where things are

| file | role |
|---|---|
| `scm2cpp-file.scm` | command-line front end |
| `scm2cpp-match.scm` | code generation |
| `type-infer-hm.scm` | type inference (Hindley-Milner, default) |
| `type-infer-match.scm` | the original relational inference |
| `alpha-conv.scm` | alpha conversion |
| `scm2cpp.hpp` | header-only C++ runtime |
| `run-tests.sh` | regression suite |

## Support

For questions about using the software, open an issue with the `question`
label.

# Binding a user's C++ template

`foo.hpp` stands in for any library the translator has never heard of: a
matrix class with `at`, `set`, `rows`. `foo-binding.scm` declares how it
is seen from Scheme -- a type constructor for the inference, one entry
per operation for the code generator, a pure Scheme model of each
operation, and a test.

```console
$ racket scm2cpp-file.scm -t scm2c.typ \
    --binding examples/custom-template/foo-binding.scm matdemo.scm
```

translates `(mat-ref m r j)` to `m.at(r,j)`, types `m` as
`foo::Matrix< double >`, and pulls `"foo.hpp"` into the includes. The
program never mentions C++.

The binding's claim -- that `foo::Matrix::at` means what the model
means -- is checked by the gate:

```console
$ racket binding-check.rkt -I examples/custom-template \
    examples/custom-template/foo-binding.scm
test 1: agree ("51.5\n3\n")
```

It runs each `binding-test` twice, once in Racket over the models and
once translated against the real header, compiled and executed, and
compares what they print. Miswiring the header -- storing column-major
while the model says row-major, say -- is exactly what it catches:

```
test 1: DISAGREE: models print "51.5\n3\n", C++ prints "26.5\n3\n"
```

The gate samples behaviour rather than proving it, the same standard the
rewrite rules are held to; give the tests boundary cases (index 0, the
last element, non-square shapes) and they will earn their keep.

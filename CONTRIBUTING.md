# Contributing to Squid

Thank you for taking the time to improve the package!

## Getting started

```bash
git clone https://github.com/PlugFox/squid.git
cd squid
make get
make all
```

`make all` runs the whole pipeline — formatting, analysis, the publishing
check and the tests — and is exactly what the CI runs on a pull request.

| Command          | What it does                                     |
| ---------------- | ------------------------------------------------ |
| `make format`    | Formats `lib`, `test` and the example            |
| `make analyze`   | Formatting check and the analyzer, warnings fatal |
| `make test`      | The package tests and the example tests          |
| `make coverage`  | The coverage report, needs `lcov` and `genhtml`   |
| `make doc`       | The API documentation into `doc/api`              |
| `make check`     | Analysis plus `pub publish --dry-run`             |

## Rules of the code

- Everything public is documented: `public_member_api_docs` is an error here.
- 80 characters per line, the formatter decides the rest.
- Every behaviour change comes with a test. The tests live in `test/` and are
  aggregated by `test/squid_test.dart`, which is the entry point used by the
  CI — a new file has to be added there.
- A change of the public API is a change of `CHANGELOG.md` as well.

## Pull requests

1. Branch from `master`.
2. Keep the change focused; unrelated cleanups deserve their own pull
   request.
3. Make sure `make all` passes.
4. Describe *why* the change is needed, not only what it does.

## Releasing

The version in `pubspec.yaml` and the changelog entry come first, then a tag
with exactly the same version publishes the package from the CI:

```bash
git tag 0.1.0 && git push origin 0.1.0
```

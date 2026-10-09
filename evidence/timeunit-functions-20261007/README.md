# `$timeunit` and `$timeprecision` system functions

IEEE 1800-2023 §20.4.1 and Syntax 20-3 define these functions as signed
integer time-scale exponents. IEEE 1800-2017 §20.4 does not include them, so
strict `-g2017` must reject them. In 2023, a no-argument call (or empty `()`)
queries the current design element. An optional hierarchical identifier selects
a module, interface, program, or package; `$unit` selects the compilation unit,
and `$root` returns the simulation time unit (global precision) for both
functions.

## Implementation

The original bare and empty-parentheses calls compiled under `-g2023` but VVP
reported both system functions as undefined. Package names also need to remain
scope identifiers through parsing. The implementation adds a narrow package-
token production that retains `PPackage` identity, adds the 2023 feature gate,
and resolves scope metadata during elaboration. No VPI registration or runtime
time-scaling change is needed.

The paired regression checks these exponents:

| Scope | `$timeunit` | `$timeprecision` |
|---|---:|---:|
| Current test module | -7 | -9 |
| Selected DUT module | -8 | -10 |
| Nested child module | -9 | -11 |
| Package | -6 | -8 |
| `$unit` | -5 | -6 |
| `$root` | -11 | -11 |

It verifies strict `-g2017` rejects both functions and that `-g2023` rejects a
non-scope numeric argument.

## Local verification

Base: `7c4aa26e084b0352a0549f4b373a6d2a18b3bb88` (`origin/main`), branch
`agent/timeunit-timeprecision-20261007`. Host: macOS ARM64.

```sh
make -j1 YACC=/opt/homebrew/opt/bison/bin/bison
make install
PATH="$PWD/local-install/bin:$PATH" bash .github/ivtest_focus_gate.sh \
  regress-timeunit-functions-focus-legacy.list \
  regress-timeunit-functions-focus-vvp.list
```

Results: build and install succeeded; focused legacy tests passed 3/3 and JSON/
VVP tests passed 3/3. Bison 3.8.2 reported 574 shift/reduce and 1122
reduce/reduce conflicts, the same totals as the base grammar.

Installed binary hashes:

| File | SHA-256 |
|---|---|
| `local-install/bin/iverilog` | `4e3504eb24e719f0356b65ab0af37e2e85d7846411d8e348461de23bd2d16953` |
| `local-install/lib/ivl/ivl` | `716cb61ee31840b95b9e874dad5a2f90d318515f505b47f7ecdd9bcfc4b1127d` |
| `local-install/bin/vvp` | `7795f1d9a205adbe5a0890e934417f4c02a06c6c7c405bbbed5be3b7a9562c29` |
| `local-install/lib/ivl/vvp.tgt` | `0f5ed97fe08fd353a25bf54327b47dbcd093abf3842cd1102da5484e0cfbe27e` |

This is local macOS evidence. No Linux source build or CI qualification is
claimed for this increment.

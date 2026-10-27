# §13.5.3 default-argument probe results

Slurm job 3737 on DAN-DESKTOP compiled and ran 12 probes in `-g2017` and
`-g2023`, each compiler and simulator process capped at 60 seconds. It used
Icarus 13.0 devel commit `cc25756d1` from the protected toolchain recorded in
`toolchain.txt`; no frontend/elaboration source files differ between that pin
and current `origin/main` (`git diff cc25756d..origin/main -- elaborate.cc
parse.y pform.cc pform.h pform_*.cc pform_*.h` was empty). Exact stdout,
diagnostics, and exit codes are in `logs/slurm-3737.out`, per-case logs, and
`status.tsv`.

| Case | 2017 and 2023 result | Assessment |
|---|---|---|
| D1 input default | `D1 f()=5` | Pass |
| D2 null class-handle default | `D2 null=1` | Pass |
| D3 output variable default | Both editions reject with `sorry: Default arguments for subroutine output or inout ports are not yet supported` and missing-argument error | Existing #633; fails required behavior |
| D4 inout variable default | Same unsupported diagnostic and missing-argument error | Existing #633; fails required behavior |
| D5 ref variable default | Unsupported diagnostic and missing-argument error | Existing #703; fails required behavior |
| D5 ref constant negative | Same unsupported diagnostic and missing-argument error | Inconclusive for the invalid-lvalue rule because defaults on `ref` are not implemented |
| D6 const-ref variable default | Unsupported diagnostic and missing-argument error | Existing #703 area; fails required behavior |
| D7 no enclosing `a` | Compiles and prints `D7 no_outer_a=2` | Contrary to lead's §13.5.3 scope reading; candidate gap |
| D7 enclosing `a=100` | Prints `D7 outer_a=2`, expected 101 from declaration-scope lookup | Contrary to lead's §13.5.3 scope reading; candidate gap |
| D8 explicit empty named argument | `D8 f(.a())=5` | Pass |
| D9 package-scope default | `D9 value=27` (caller module has `gv=99`) | Pass |
| F1 constant-function fork (#638 reproducer) | Both editions compile and run successfully | Existing #638 gap reproduced |

The F1 source is identical in substance to the reproducer in open issue #638.
The fresh open+closed issue search found no match for the D7 behavior; details
and query terms are in `DEDUPE.md`. No new issue has been filed by the runner.

Slurm reports `ExitCode=0:0`, requested memory 1 GiB, and runtime rounded to
0 seconds. `sstat` had no completed batch step, so peak RSS is unavailable.

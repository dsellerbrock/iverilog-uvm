# IEEE 1800 clause 19 probe batch C — bisection

Slurm job 2266 on DAN-DESKTOP (1 CPU, 1 GiB) ran both language modes with the protected Icarus 13.0 devel toolchain from source revision `9b5fad2af`. Binary SHA-256 values and exact compiler output are in `results.txt`; per-case logs and the input files are preserved beside it. The job completed normally with `script_exit=1` because expected-positive probes exposed findings.

| Probe | 2017 | 2023 |
|---|---|---|
| Two-argument coverpoint `get_inst_coverage(cov, tot)` | Compile error: unknown task `g.cp.get_inst_coverage` | Same compile error |
| Two-argument covergroup `get_inst_coverage(cov, tot)` after one sample | Compiles/runs, prints `cov=0 tot=0` | Same result |
| Implicit coverpoint name control | Explicit label `v:` passes at 25% | Same result |
| Minimal embedded `covergroup extends` | Rejected, as edition-only syntax | Syntax error at the `extends` declaration |
| Undefined-base negative | Generic syntax error | Generic syntax error; no base-specific diagnostic |

The omitted-label positive probe is in attempt 01; it fails lookup of `g.v` in both modes while the explicit-label control passes. The initial attempt's undefined-base marker was a filename-matching bug and is documented in attempt 01; this bisection is the corrected diagnostic evidence. The lead classified clocking-event sampling as implemented (§19.3), the two-argument getter failures under existing #622, implicit coverpoint naming as partial (#630), and 2023 embedded inheritance as missing under existing #457.

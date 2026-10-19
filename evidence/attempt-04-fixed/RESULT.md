# #680 T0/T1 — fixed source and runner layout

- Slurm job 2891 on DAN-DESKTOP, 3 CPUs, 6 GiB, elapsed 3:19, exit `0:0`. `sstat` and `sacct` could not retrieve peak RSS after completion.
- Base commit: `82023726be90ab269d6e0ef5e755ebb69e6f648c`.
- Icarus 13.0 devel compiler SHA-256: `234d4e6ee4a27f636b1b07de19e31db0ea510601945ed5aaf2885edb8e1d4f42`; VVP SHA-256: `2c18f1c5cfc8519fc72ede80878efb500d3187c681472c5935f3bb59388e0350`.
- T0 issue reproducer: passed in both `-g2017` and `-g2023`.
- T0 smoke: passed. Perl smoke 56/56, VPI 133/133, negative diagnostics 152/152, and all VVP runtime checks passed.
- T1 legacy constraint-function suite: 229/229 passed.
- T1 JSON constraint-function suite: 230/230 passed, including the new 2017/2023 `this.data` expected-compile-error pair and the positive package-function regression.
- Raw logs and per-test JSON results are in `a3-680-attempt-04-results.tar.gz`; the runner source is `build-and-t1.sbatch`.

# Issue #680 baseline reproduction

- Source base: `origin/main` at `82023726be90ab269d6e0ef5e755ebb69e6f648c`; `git diff` against staged source `4bfe7d04ca190adc9ad74268445bf42a6f187f59` was empty.
- Host: DAN-DESKTOP; Slurm job 2877, requested 1 CPU / 2 GiB.
- Toolchain: `/home/dsell/toolchains/iverilog-uvm-4bfe7d04`; hashes in `results/tool-binaries.sha256`.
- Exact inputs and hashes: [`issue-repro.sv`](issue-repro.sv), [`control-precomputed.sv`](control-precomputed.sv), `results/input-sha256.txt`.
- Raw compiler output: [`results/combined.log`](results/combined.log); Slurm stdout: [`logs-a3-680-repro-2877.out`](logs-a3-680-repro-2877.out).

With `-g2017 -gassertions` and `-g2023 -gassertions`, the package-function call inside the inline constraint failed compilation in both editions with `constraint ... could not be translated and the randomize call cannot be compiled` (exit 1). The equivalent control that computes `wr_mask = get_mask(rname)` before `randomize()` compiled and ran in both editions, printing `PASS issue 680 precomputed-mask control` (exit 0). The harness completed with `GATE_RESULT=PASS`; the expected failure/control behavior was reproduced.

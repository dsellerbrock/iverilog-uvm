# IEEE 1800 clause 13 audit, c13a

Probe scope: §§13.5.1–13.5.3 (call forms, value/ref passing, defaults), both editions; §13.5.2 `ref static` (2023 addition).

Attempt 01 ran on DAN-DESKTOP using Slurm job 2289 (1 CPU, 1 GiB, 10-minute cap; per compile 30 seconds and per simulation 10 seconds, TERM then KILL after 2 seconds). The job reached `FAILED`, `ExitCode=1:0` in one second because the probe correctly reported failures; this is a test result, not infrastructure loss. Icarus 13.0 devel source `9b5fad2af`; `iverilog` SHA-256 `6cd9749cb1e981820f64fdc737ae458bf6c46e3fcad8927afaf92649ee9a3288`, `vvp` SHA-256 `c2474d2a745aa7d896885202314a5244ee26af56a32dda59a6c8fbd3ba362e3a`.

The broad positive probe failed compilation in both editions at its output-formal default (`sorry: Default arguments for subroutine output or inout ports are not yet supported`), so its other positive checks are inconclusive until bisected. Isolated 2023 `ref static` compiled and ran PASS; 2017 rejected it with the edition diagnostic. `ref` in a static-lifetime function was unexpectedly accepted in both editions. The other negative probes were rejected: net ref actual (diagnostic says the wire is not a valid l-value), `ref input` syntax, const-ref write, ref type mismatch, and omitted required argument. The unresolved output default was rejected only by the unsupported-output-default diagnostic, so it does not prove unresolved-name rejection. The 2023 automatic actual to `ref static` was rejected with the expected static-lifetime diagnostic; 2017 rejected that source as edition-only.

Full raw output and per-case logs: [`attempt-01/logs/results.txt`](attempt-01/logs/results.txt) and the sibling `*.log` files. Exact submitted script: [`attempt-01/a3-m7-c13a.sbatch`](attempt-01/a3-m7-c13a.sbatch). Local source/dirty-state and source hashes: [`manifest.txt`](manifest.txt).

The 2017 PDF p.331–332 excerpt confirms §13.5.2 describes `ref` and its static-subroutine restriction; `ref static` does not appear there. §13.5.2 `ref static` is edition-specific to 2023.

Attempt 02 isolated the standard-valid parts: the remaining 15 positive checks all pass in both editions. It confirms two gaps: explicit and implicit static-lifetime subroutines accept ordinary `ref` (`#632`), and output/inout formal defaults are unsupported in both editions (`#633`). The issue-body check found #449 covers `ref static` arguments, not the static-lifetime prohibition; #477 covers equivalent types. The 2017 printed p.332 §13.5.3 text explicitly permits defaults on `input`, `inout`, `output`, and `ref` arguments and defines per-call evaluation.

The audit lead classified the tested subsets of §13.5.1 as IMPLEMENTED, §13.5.2 as PARTIAL, and §13.5.3 as PARTIAL. Other §13.5 features remain unassessed. Full duplicate-search output: [`attempt-02/duplicates.txt`](attempt-02/duplicates.txt).

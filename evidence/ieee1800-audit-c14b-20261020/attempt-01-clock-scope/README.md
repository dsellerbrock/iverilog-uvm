# §14.7 clocking-block scope probe

IEEE 1800-2017 §14.7 p. 340 and IEEE 1800-2023 §14.7 p. 358 prohibit clocking blocks in tasks, packages, or at compilation-unit scope, and allow them in modules, interfaces, checkers, and programs. This probe fills the prior matrix's checker/program/compilation-unit scope gap.

- Host: DAN-DESKTOP, Slurm job 3580; `scontrol` reports `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, runtime 0 s.
- Compiler source: refreshed `origin/main` `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; shared read-only toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Icarus/VVP SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- Both `-g2017` and `-g2023`: program clocking test compiles/runs and prints `PASSED`; checker default-clocking test compiles/runs and prints `PASSED`; explicit named clocking block inside a checker compiles/runs and prints `CHECKER_CLOCKING_SCOPE_OK`; compilation-unit clocking declaration fails compile with exit 2 and a syntax error at the clocking declaration.
- Every compile/runtime used `timeout -k 2 30`. Per-case statuses and raw logs are in `remote-3580/results/`; staged source hashes are in `input.sha256`.

Open+closed dedupe for §14.7 / checker / program / compilation-unit scope found no existing issue. Matches #773 (let declarations), #679 (sampled-value default clocking), #44 and #17 (closed parser/feature history) do not cover this rule. No gap was observed in the tested scope subset, so no issue was filed.

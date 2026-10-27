# §15.5.3 event-formal current-main rerun

IEEE 1800-2017 §15.5.3 p. 361 and IEEE 1800-2023 §15.5.3 give the generic task example `task trigger(event ev); -> ev; endtask`. This rerun uses that declaration/call, an isolated declaration, and an ordinary task-formal control.

- Host: DAN-DESKTOP, Slurm job 3579; 1 CPU, 1 GiB; every compile and runtime capped at 30 seconds. `scontrol` confirmed `COMPLETED`, `ExitCode=0:0`, runtime 1 s.
- Compiler source: refreshed `origin/main` `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; pinned read-only toolchain `/home/dsell/toolchains/iverilog-fb584a25-20261020`.
- Compiler/vvp SHA-256: `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c` / `7fa3224c44e69b555fa86c1e3e048fa2709780276c6418ff8b7a7f0d63241c02`.
- Both `-g2017` and `-g2023`: isolated and standard-form event-formal declarations fail with exit 2 and `syntax error` at the formal; ordinary `input int` task formal control compiles with exit 0. The standard-form task therefore cannot run. All raw logs and exit codes are in `remote-3579/results/`.
- Probe hashes: `input.sha256`.

Open+closed issue search finds existing #829 for this exact §15.5.3 gap; #699 (event handles), #439 (triggered), #441 (wait_order), and #635 (function argument placement) do not cover this task-formal parser failure. No duplicate issue was filed. The lead owns the current-main evidence comment and classification.

# Results — §19.8 type coverage depth

- Slurm job 3730 on DAN-DESKTOP: completed, exit 0; 1 CPU, 1 GiB, 15-minute limit, reported runtime under one second.
- Compiler: Icarus Verilog 13.0 devel, source/toolchain commit `cc25756d187314742d347267c2a513b3e640a7fb`, protected root `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`.
- SHA-256: `iverilog` `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Command for each input/edition: `timeout --signal=TERM --kill-after=10s 60s "$IVL_ROOT/bin/iverilog" -B "$IVL_ROOT/lib/ivl" -g{2017,2023} -o results/<case>-g<edition>.vvp input/<case>.sv`; when compile succeeds, `timeout --signal=TERM --kill-after=10s 60s "$IVL_ROOT/bin/vvp" results/<case>-g<edition>.vvp`.

| Case | 2017 | 2023 |
|---|---|---|
| T1 `cg::get_coverage()` | Compile fails: `No function named cg.get_coverage` | Same |
| T2 `cg::cp::get_coverage()` | Compile fails: `No function named cg.cp.get_coverage` | Same |
| T3 `c1.get_coverage()` plus `(cov,tot)` | `75.00`; ref form returns `75.00`, `cov=0 tot=0` | Same |
| T4 `c1.cp.get_coverage()` | `75.00` | `75.00` |
| T5 `c1`, `c1.cp`, `c2` `get_inst_coverage()` | `50.00`, `50.00`, `50.00` | Same |
| T6 `cg::get_coverage(cov,tot)` | Compile fails: `No function named cg.get_coverage` | Same |

Each edition's compile and simulation return codes are in `results/status.tsv`; raw diagnostics and stdout are in `logs/`. The run script, exact test inputs and hashes are retained in this directory.

## Issue dedupe

`gh issue list --repo dsellerbrock/iverilog-uvm --state all --search '"get_coverage" "covergroup"'` and the corresponding `coverpoint` search found open #627 and #622, plus closed historical issues #7 and #19. No new issue is indicated by these probes: T1/T2/T6 confirm #627, and T3's zero ref outputs overlap the existing two-argument coverage defect tracked by #622.

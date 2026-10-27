# §20.4.1 time-unit retrieval probe — 2026-10-20

IEEE 1800-2023 §20.4.1 introduces `$timeunit` and `$timeprecision`. The section says: “The return value shall be an integer in the range from 2 to -15.” Table 20-2 maps the selected units to `1 ns = -9`, `1 ps = -12`, `100 us = -4`, and `10 ns = -8`. The 2017 text contains neither system function, so rejection in that edition is the control. See `STANDARD.md` for scope and exact references.

## Run

- Slurm job 3543 on DAN-DESKTOP, toolchain cc25756d1; 1 CPU, 1 GiB, 10-minute limit; start 2026-10-20 12:52:38 UTC, end 12:52:39 UTC, `COMPLETED`, exit 0, elapsed 1 s.
- Command: `iverilog -B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl -g{2017,2023} -s <module> -o <module>.vvp <module>.sv`; `p20_04_1_tu` then ran with `vvp`. Each process had a 30 s timeout.
- Compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; `ivl`/`ivlpp` and source hashes are in `slurm-3543.out`.
- Slurm accounting is disabled and completed-job `sstat` returned no data; peak RSS is unavailable. Requested memory was 1 GiB based on earlier similarly sized probes.

## Results

- Scalar two-`always_comb` control: compile accepted in both editions (see #862).
- `p20_04_1_tu`, `-g2017`: compile rejected with the edition diagnostic requiring `-g2023`.
- `p20_04_1_tu`, `-g2023`: compile/run pass; `TU -9 -12 -4 -8`.

## Issue dedupe

Open and closed issues were searched for `$timeunit`, `$timeprecision`, and `20.4.1`; raw results are in `dedupe-*.json`. Closed #458 already covers implementing these system functions and their edition behavior. #545 concerns implicit timescale policy and is unrelated. No new issue was filed; the additional result was recorded in [a comment on #458](https://github.com/dsellerbrock/iverilog-uvm/issues/458#issuecomment-6298681644).

The exact remote Slurm run directory was 13,760 bytes and was removed after recording these results here.

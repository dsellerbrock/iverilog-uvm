# §11.5.3 longest static prefix probe — 2026-10-20

IEEE 1800-2017 and 1800-2023 §11.5.3 define static array indexing in terms of constant index expressions and give the same three longest-static-prefix examples. IEEE 1800-2017 §9.2.2.2 and 1800-2023 §9.2.2.2 require `always_comb` assignment variables not to be written by another process, while permitting independent elements if their longest static prefixes do not overlap. Exact text is in `STANDARD.md`.

## Run

- Slurm job 3542 on DAN-DESKTOP, toolchain cc25756d1; 1 CPU, 1 GiB, 10-minute limit; start 2026-10-20 12:49:42 UTC, end 12:49:42 UTC, `COMPLETED`, exit 0, elapsed 0 s.
- Each compile used `iverilog -B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl -g{2017,2023} -s <module> -o <module>.vvp <module>.sv`; the positive control then ran with `vvp`. Every process had a 30 s timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; helper hashes and source hashes are in `slurm-3542.out`.
- Slurm accounting is disabled and completed-job `sstat` returned no data; peak RSS is unavailable. Requested memory was 1 GiB based on earlier similarly sized clause audit jobs.

## Results (both editions)

- `p11_05_3_lsp`: compile/run pass; `L1 11 22`.
- `n11_05_3_lsp_dynamic`: compile accepted (rc 0); compile-only negative, no runtime.
- `n11_05_3_lsp_overlap`: compile accepted (rc 0); compile-only negative, no runtime.

Both disjoint positive and overlapping negative controls are preserved. The overlap cases are accepted even though §9.2.2.2 says overlapping longest static prefixes must not be assigned by separate `always_comb` processes. A same-scalar two-process control also compiled in both editions in job 3543 (see [the scalar control evidence](../../ieee1800-audit-c20b-20261020/attempt-01-timeunit/README.md)). The audit lead filed [#862](https://github.com/dsellerbrock/iverilog-uvm/issues/862); the scalar scope note is [commented there](https://github.com/dsellerbrock/iverilog-uvm/issues/862#issuecomment-6298678522).

## Issue dedupe

Open and closed issues were searched for `longest static prefix`, `always_comb multiple drivers`, `always_comb written by another process`, and `11.5.3`; raw results are in `dedupe-*.json`. The only hit was closed #472, a §6.5 mixed-driver issue about a dynamic packed subpart under an otherwise disjoint prefix. It does not cover multiple `always_comb` processes writing overlapping unpacked-array prefixes.

The exact remote Slurm run directory was 22,666 bytes and was removed after the results were recorded here.

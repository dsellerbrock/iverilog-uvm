# §11 aggregate conditional isolate — 2026-10-20

IEEE 1800-2017 and 1800-2023 §11.4.11 permit conditional operators on aggregate expressions. If the condition is ambiguous, fixed unpacked arrays of equal element count combine element by element. The exact source text and clause references are in `standard.md`.

## Run

- Slurm job 3541 on DAN-DESKTOP, cc25756d1; 1 CPU, 1 GiB, 15-minute limit; start 2026-10-20 12:46:52 UTC, end 12:46:53 UTC, `COMPLETED`, exit 0, elapsed 1 s.
- Command: `iverilog -B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl -g{2017,2023} -s <module> -o <module>.vvp <module>.sv`, followed by `vvp <module>.vvp`; each compile/run had a 30 s timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; pinned `ivl`/`ivlpp` hashes are in `slurm-3541.out`.
- Slurm accounting is disabled and completed-job `sstat` has no data, so peak RSS is unavailable. Requested memory was 1 GiB based on prior identical audit probe jobs.

## Results (both editions)

- `k11_02_ka`: compile/run pass; `K 5 6 6`, `E 1 1 1 1`, `Y 2 7`. Constant function/system function, 1-D array and struct equality, and aggregate copy work.
- `q11_02_qa`: compile fails at runtime-condition array ternary with `sorry: a conditional with whole unpacked array operands is only supported when the condition is a constant.`
- `q11_02_qs`: compile/run pass; `QS 3`. Struct conditional works with a variable condition.
- `q11_02_qx`: compile fails with the same array-conditional diagnostic; ambiguous array merge is masked by the missing array conditional support.
- `q11_02_qk`: compile/run pass; `QK 2`. Constant-condition array ternary control works.

Thus the §11.4.11 gap appears limited to whole unpacked-array conditional operands with a nonconstant condition. The ambiguous-condition element merge still needs independent coverage if it can be isolated without this unsupported operation. The audit lead filed [#861](https://github.com/dsellerbrock/iverilog-uvm/issues/861); the issue records the expected ambiguous merge.

## Issue dedupe

Open and closed GitHub issues were searched with `sorry conditional`, `whole unpacked array operands`, `conditional aggregate`, `ternary unpacked`, `conditional struct`, and `11.4.11`; raw JSON is in `dedupe-*.json`. No direct issue matched. #775 (conditional in let with cast) and #780 (conditional-operator predicate in assertion syntax) are unrelated.

The staged source was unchanged during job 3541; its remote hashes are preserved in `slurm-3541.out`. The disposable remote run directory was 40,752 bytes and was removed after recording these results.

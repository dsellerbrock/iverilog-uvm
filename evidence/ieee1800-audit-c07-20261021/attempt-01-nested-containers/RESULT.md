# Clause 7 nested-container results

Slurm job 3760 on DAN-DESKTOP used Icarus 13.0 devel `cc25756d1`, pinned at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, with `-B`, `-g2017` and `-g2023`. The job requested 1 CPU and 1 GiB; each compile/run had a 30-second cap. Slurm reports `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, runtime rounded to 0 seconds. Accounting storage is disabled, so peak RSS is unavailable. Raw logs, status, toolchain hashes and `scontrol` output are under `raw-slurm-3760/`.

| Case | Both editions | Observed output/result | Expected |
|---|---|---|---|
| A1 associative array of queues | compile/run 0/0 | `2 2 2 3` | Match |
| A2 queue value copy | 0/0 | `1` | Match |
| A3 `foreach` over associative queue | 0/0 | `a0=1`, `a1=2`, `b0=3` | Match, in order |
| A4 class method through associative element | 0/0 | `6` | Match |
| A5 dynamic array of queues | 0/0 | `2 0 4` | Match |
| A6 class-queue `find` and `find_first_index` | 0/0 | `2 1` | Match |
| A7 class-queue `sort with (item.v)` | 0/0 | `1 2 3` | Match |
| A8 class-queue `sum with (int'(item.v))` | compile rc 1 | `Array reduction method sum() requires an array of integral elements` | Excluded: §7.12.3 restricts reductions to unpacked arrays of integral elements; this rejection is not a conformance gap |
| A9 class-handle equality in `find_first` | 0/0 | `1` | Match |
| A10 push into a missing associative key's queue | 0/0 | `3 7` | Match |

All paired cases agree across editions except A8, which fails to compile in both with the same diagnostic. The audit lead checked IEEE 1800-2017/2023 §7.12.3 and ruled A8 outside its required domain: reduction methods apply to unpacked arrays of integral values, so a `with` cast does not make a queue of class handles a conformance case. A8 is recorded as an excluded compatibility note, and no issue was filed. Open/closed dedupe is in [`DEDUPE.md`](DEDUPE.md).

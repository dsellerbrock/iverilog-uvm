# §16.6–§16.7 paired probe results

Slurm job 3754 on DAN-DESKTOP; Icarus 13.0 devel `cc25756d1`; `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`, `-gassertions`, `-g2017` and `-g2023`. Requested 1 CPU, 1 GiB, 6 minutes, with a 30-second timeout for every compile and simulation. The Slurm job completed `ExitCode=0:0` in one second; the harness continues after per-test failures, so per-case status below controls interpretation. Accounting storage is disabled, so peak RSS is unavailable.

| Cases | 2017 / 2023 result | Interpretation |
|---|---|---|
| B1/B2 | compile/run 0/0; X and Z each fail at t=5,15,25,35,45,55,65,75 | Matches the expected false treatment of X/Z. |
| NB1 | compile rc 0 both; emits `Assignment l-value too complex.`; run prints FAIL at every tick | The forbidden `cnt++` property expression is accepted despite the diagnostic, and its counter does not advance. |
| NB2 | compile/run 0/0 both; warning says the chandle operand is read live; no FAIL action | The forbidden chandle reference is accepted with a warning. |
| NB3 | compile/run 0/0 both; warning says the non-static class property cannot be sampled and is read live; no FAIL action | The forbidden class-property reference is accepted with a warning. |
| NB4 ref argument | compile rc 1 both; `Assignment l-value too complex.` and one elaboration error | Rejected, as expected. |
| NB5 inout argument | compile rc 1 both with the same diagnostic | Conforming: although 2017 does not list `inout` explicitly, copy-back violates its separate no-side-effects rule; 2023 names `inout` explicitly. |
| Q1/Q4/Q6/Q7/Q8 | compile/run 0/0; no FAIL actions | Matches the expected delay behavior. Q7 leaves an unbounded weak obligation pending at simulation end. |
| Q2 | compile/run 0/0; one FAIL at t=25 | Matches. |
| Q3 | compile/run 0/0; one FAIL at t=45 | Matches. |
| Q5 | compile/run 0/0; one FAIL at t=55 | Matches. |
| NQ1 | compile aborts with rc 134 in both editions: `std::length_error`, `vector::reserve` | Invalid reversed range crashes the compiler instead of producing the required static diagnostic. |
| NQ2 | compile rc 1 both; compiler says `sorry: sequence cycle delays must be literal constants; the assertion is dropped.` | Rejected with an explicit diagnostic; runtime is not attempted. |

All 34 compile/run status entries and raw compiler/runtime logs are under `raw-slurm-3754/`. `scontrol.txt`, toolchain hashes, and staged source hashes are retained there and at the attempt root. Input and script hashes were identical before and after staging. The generated remote `.vvp` files and staged input copies were removed after evidence was copied.

## Dedupe and next decision

The fresh open/closed search is recorded in `DEDUPE.md` and `dedupe-all-issues.json` (416 issues: 289 open, 127 closed). It found #713's variable-length `first_match` continuation and closed #18's broad historical SVA phase issue, neither of which covers these cases. No exact reversed-range compiler-crash match was found. After reviewing the IEEE text and searching independently, the lead filed [#913](https://github.com/dsellerbrock/iverilog-uvm/issues/913) for the dropped increment side effect, [#914](https://github.com/dsellerbrock/iverilog-uvm/issues/914) for the grouped live-read operand restrictions, and [#915](https://github.com/dsellerbrock/iverilog-uvm/issues/915) for the reversed-range compiler abort. The lead confirmed NB5 rejection is conforming in both editions because inout copy-back is a side effect under 2017 §16.6; NQ2 returns a compile error as required.

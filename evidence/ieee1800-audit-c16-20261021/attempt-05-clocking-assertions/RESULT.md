# §16.18 clocking-block assertion results

Slurm job 3758 on DAN-DESKTOP used Icarus 13.0 devel `cc25756d1`, pinned at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, with `-gassertions`, `-g2017` and `-g2023`. The job requested 1 CPU and 1 GiB; every compile and simulation had a 30-second limit. Slurm reports `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, with runtime rounded to 0 seconds. Accounting storage is disabled, so peak RSS is unavailable. Raw logs, status, toolchain hashes and `scontrol` output are under `raw-slurm-3758/`.

| Case | Compile/run in both editions | Observed | Interpretation |
|---|---|---|---|
| K1, standard a1 | 0/0 | `K1 FAIL 15` only | Matches the direct-variable baseline. |
| K2, standard a3 | 0/0 | `K2 FAIL 5`, `K2 FAIL 25`; no failure at 15 | Differs from K1; the clocking-block input's observed sequence is one edge out of phase with the equivalent direct variable in this test. |
| K3, standard a2/a4 forms | compile rc 18 | Syntax/invalid-module-item errors at property declarations inside clocking blocks, followed by recovery diagnostics | Blocked by existing #917; no separate issue from this probe. |
| E1, clocking input `#3` | 0/0 | No compile diagnostic; `E1 FAIL 5`, `15`, `25` | A non-`#1step` input skew is accepted rather than rejected. |
| E2, clocking input `#0` | 0/0 | No compile diagnostic; `E2 FAIL 5`, `15`, `25` | A non-`#1step` input skew is accepted rather than rejected. |

The local standards say in §16.18 that if a variable used in a concurrent assertion is a clocking-block variable, “it will be sampled only in the clocking block,” and the standard's a1–a4 assertions are equivalent (2017 pp. 482–483; 2023 pp. 501–502). K1 and K2 use the same `a` transition and clock. K1 fails only at 15, but K2 fails at 5 and 25, so the equivalence does not hold in either edition.

The related §16.5.1 rule says: “If a variable is an input variable of a clocking block, the variable shall be sampled by the clocking block with #1step sampling. Any other type of sampling for the clocking block variable shall result in an error” (2017 p. 375; 2023 p. 394). E1/E2 compile cleanly in both editions, despite using `#3` and `#0` input skews.

Open/closed dedupe is in [`DEDUPE.md`](DEDUPE.md). The audit lead confirmed two distinct gaps and filed [#919](https://github.com/dsellerbrock/iverilog-uvm/issues/919) for the §16.18 one-edge clockvar lag, and [#920](https://github.com/dsellerbrock/iverilog-uvm/issues/920) for accepting non-`#1step` input skews in concurrent assertions. Standard a2/a4 remain blocked by #917.

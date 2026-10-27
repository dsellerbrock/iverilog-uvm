# Clause 31 final timing-check results

Slurm job 3689 ran on DAN-DESKTOP with 1 CPU and 1 GiB requested. `scontrol` recorded `COMPLETED`, exit `0:0`, and a sub-second runtime; `sacct` reported that accounting storage is disabled, so peak RSS is unavailable. The pinned Icarus source commit was `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; compiler SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`. Scheduler stdout and every compile/run log are preserved in [`raw-slurm-3689`](raw-slurm-3689/).

## Positive checks

`p31_tchk3.sv` compiled and ran with exit 0 under both `-g2017 -gspecify` and `-g2023 -gspecify`. Both editions reported eight notifier changes and final value 0 (`N 8 0`). `$recrem` reported recovery at t11 and removal at t21. Edge `[01]` produced one report for 0→1 and none for 0→x or x→1. The `&&&` data event reported only with enable high. A single bit change in a four-bit timing signal produced one report.

The skew checks reported at t43 (`$timeskew`), t63 (reference-first `$fullskew`) and t73 (data-first `$fullskew`). With 1 ns precision and limit 2, each is also the first time step at which elapsed time exceeds the limit, so the late events cannot distinguish timer-based from event-based reporting. The lead assigned a separate no-data/late-data probe to settle default-mode behavior.

## Negative timing checks

`p31_neg.sv` compiled and ran without an extra option under both editions. It reported a `$setuphold(hold)` violation at t11, then printed `A q=0 nc=1`; the standard-based expected result is `A q=1 nc=0`. At t44 it reported another hold violation and printed `B nc=2`; the expected result for the in-window event is one violation total (`B nc=1`).

Compiler help lists `-gspecify` but no negative timing-check option. Runtime help and the Icarus manual likewise list no such option. The explicit candidate `-gneg_tchk` was rejected with exit 255 as `Unknown/Unsupported Language generation neg_tchk`. The negative-limit behavior in both editions therefore does not meet §31.9.1's delayed-signal/latched-data result. No specific delay for `dclk` or `dd` is assumed.

The seven open+closed GitHub issue searches returned no matches before filing #890; see [`DEDUPE.md`](DEDUPE.md). The lead classified §31.9 as unsupported and filed [#890](https://github.com/dsellerbrock/iverilog-uvm/issues/890). It classified the tested subsets of §31.3.6, §31.5, §31.7 and §31.8 as implemented. Only §31.4.2–§31.4.3 remain unresolved; their no-data/late-data follow-up is in [attempt 04](../attempt-04-skew-timer/README.md). Clause 31's issue count increased by one.

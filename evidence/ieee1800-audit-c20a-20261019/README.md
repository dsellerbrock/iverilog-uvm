# IEEE 1800 §20.2–§20.5 audit probes

Probes ran on macOS ARM64 with the Icarus build from `b9441bafbdb0b6b7413c09e0381845e69481391b`, under `~/codex-supervisor/localrun`, for both `-g2017` and `-g2023`. Tool hashes, source hashes, per-test compiler/runtime output, host, and checkout state are in `attempt-01-time-conv-systasks/`.

## Time and conversion probe

`p20_03a_time_conv.sv` fails compilation in both editions at the constant real parameter `$bitstoreal(64'h4000000000000000)`: Icarus reports “Unable to evaluate real parameter PR value.” The isolated `r20_05_bitstoreal_constant.sv` fails with the same diagnostic in both editions, while the real-literal control `r20_05_real_constant_control.sv` compiles in both. Because the combined file does not elaborate, it provides no result for `$time`, `$realtime`, `$stime`, `$timeformat`, `$printtimescale`, or the remaining conversion checks. Raw minimal-reproducer output and hashes are in `attempt-02-bitstoreal-constant/`.

## Finish and exit tasks

All finish/exit probes compile and run with exit code 0 in both editions:

- `$finish(0)` and default `$finish` produce their expected quiet/diagnostic forms.
- `$finish(1)` reports the source location and simulation time.
- `$finish(2)` prints the same location/time diagnostic but no simulator statistics.
- The `$exit` probe prints `EX0`; it does not print `PROG done` from the program block or `LATE` from the module.

These are raw observations only; the audit lead has not classified the outcomes or filed issues yet. The complete run took 1.88 seconds under localrun, with 18,513,920 bytes maximum resident set size.

## Corrected reducers (attempt 06)

Attempts 03–05 are harness-invalid and are not evidence: attempt 03 removed neighboring declarations while editing the source, attempt 04 inherited that broken source and had a bad source-list path, and attempt 05 had an unmatched quote in its runner and executed no probes. The inputs and logs are retained in their attempt directories.

Attempt 06 reran the corrected time probe, seven isolated constant-expression reducers, and both `$exit` contexts in `-g2017` and `-g2023`. It ran sequentially on macOS ARM64 with the same Icarus/vvp hashes recorded in `attempt-06-clean-run/`, under `localrun` with a 10-second limit per compile or simulation. The corrected runtime probe reports `pass=13 fail=0` in both editions and identical time-format/timescale output. Constant `$rtoi` and `$itor` compile and run; `$bitstoreal`, `$realtobits`, `$shortrealtobits`, `$bitstoshortreal`, and the nested `$bitstoreal($realtobits(...))` reducer fail elaboration in both editions. Program-context `$exit` and module-context `$exit` both return successfully with no output beyond `EX0` for the module-context case.

The audit lead classified these as three distinct §20 gaps after open/closed issue searches and filed [#785](https://github.com/dsellerbrock/iverilog-uvm/issues/785) (`$bitstoreal` and related conversions in constant expressions), [#786](https://github.com/dsellerbrock/iverilog-uvm/issues/786) (`$exit` in a program), and [#787](https://github.com/dsellerbrock/iverilog-uvm/issues/787) (`$finish(2)` statistics). GitHub confirmed all three are open with the `1800-audit` label. New issue count for this tranche: §20.2 +2, §20.5 +1.

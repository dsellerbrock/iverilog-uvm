# §16.5.1 time-zero assertion sampling control

IEEE 1800-2017 and 1800-2023, `-gassertions`, pinned Icarus 13.0 devel `cc25756d1`; Slurm job 3753 on DAN-DESKTOP. The run used 1 CPU, 1 GiB, a 5-minute job limit, and a 30-second timeout for each compile and simulation. All four compile/run pairs returned 0.

| Probe | Edition | Compile/run | Output | Interpretation |
|---|---:|---:|---|---|
| S3d: constant-false assertion on `posedge c0` | 2017 | 0/0 | `S3d FAIL 0` | A concurrent assertion attempt occurs at time zero. |
| S3d | 2023 | 0/0 | `S3d FAIL 0` | Same. |
| S3e: assert time-zero sampled `v`, initialized to 0 then assigned 1 in `initial` | 2017 | 0/0 | `S3e PASS 0` | The assertion sees 1, not the expected default sampled value 0. |
| S3e | 2023 | 0/0 | `S3e PASS 0` | Same. |

The two sources, per-case logs, job stdout/stderr, status table, toolchain identity, binary/source SHA-256 values, and exact batch script are preserved here. Toolchain binaries were Icarus 13.0 devel `(cc25756d1)`, SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593` for `iverilog` and `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb` for `vvp`.

Slurm reports `COMPLETED`, `ExitCode=0:0`; runtime was rounded to `00:00:00`; accounting storage is disabled, so peak RSS is unavailable. The host was reachable and the job ran to completion. Generated remote `.vvp` files and staged source copies were removed after copying the logs and result metadata.

The standard's §16.5.1 default-sampling rule applies: a static variable's default sampled value is the value assigned in its declaration, and a variable's sampled value at time zero is its default sampled value (2017 printed p. 374; 2023 printed p. 393). Here the declaration assigns `v=0`; the later `initial v=1` must not change that time-zero sampled value.

## Dedupe

A fresh GitHub snapshot at `dedupe-all-issues.json` included 415 open and closed issues (288 open, 127 closed). Searches of titles and bodies for time-zero/time zero, default sampled value, sampled value, Preponed, and assertion sampling found related but different issues: #709 is specifically procedural `$sampled` returning a live value; closed #496 is procedural `$past` operand sampling; #910 concerns parsing `const'` casts. No issue in that snapshot covered concurrent assertion default sampling at time zero. After verifying both editions' §16.5.1 wording and independently searching the issue tracker, the lead filed [#912](https://github.com/dsellerbrock/iverilog-uvm/issues/912).

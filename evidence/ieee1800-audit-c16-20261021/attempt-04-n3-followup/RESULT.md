# §16.16 N3 binding follow-up results

Slurm job 3757 on DAN-DESKTOP used Icarus 13.0 devel `cc25756d1`, pinned at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, with `-gassertions`, `-g2017` and `-g2023`. The job requested 1 CPU and 1 GiB; every compile and simulation had a 30-second limit. Slurm reports `COMPLETED`, `ExitCode=0:0`, 1 CPU, 1 GiB, with runtime rounded to 0 seconds. Accounting storage is disabled, so peak RSS is unavailable. Raw logs, status, toolchain hashes and `scontrol` output are under `raw-slurm-3757/`.

| Case | 2017 | 2023 | Result |
|---|---|---|---|
| N3a named property in procedural `|=>` consequent | compile rc 1 | compile rc 1 | `Unable to bind wire/reg/memory 'q1' in 'tb'` |
| N3b named property asserted directly | compile/run 0/0 | compile/run 0/0 | `N3b FAIL 60`, `N3b FAIL 70`, and an extra `N3b FAIL 80` at the coincident `$finish` boundary. The expected 60/70 failures prove property evaluation; the 80 boundary artifact is not used for classification. |
| N3c original named property with explicit posedge used under inferred negedge | compile rc 1 | compile rc 1 | `Unable to bind wire/reg/memory 'q2' in 'tb'`; no rule-specific multiclock diagnostic. |
| N3d named property in module-level `|=>` with explicit outer clock | compile rc 1 | compile rc 1 | `Unable to bind wire/reg/memory 'q1' in 'tb'` |

The control separates named-property instantiation from its use as an implication consequent: directly asserting named property `q5` evaluates in both editions, but named properties `q1`/`q2` used as the consequent of `|=>` do not bind in either a procedural assertion or a module-level assertion. The audit lead verified IEEE 1800-2017 §16.12.1 p. 423 and IEEE 1800-2023 §16.12.1 p. 442 onward: “An instance of a named property can be used as a property_expr or property_spec.” It filed [#918](https://github.com/dsellerbrock/iverilog-uvm/issues/918) for this gap. N3c therefore does not test whether the required §16.16 rule (c) multiclock diagnostic is emitted; that check remains blocked by #918. The matching open/closed dedupe search is recorded in [`DEDUPE.md`](DEDUPE.md).

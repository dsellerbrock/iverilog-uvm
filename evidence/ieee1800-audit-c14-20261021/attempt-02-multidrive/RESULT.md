# Paired Clause 14 / Clause 16 probe results

## Run 1 — Slurm job 3749

- Host: DAN-DESKTOP; job 3749 completed `COMPLETED`, exit 0, runtime 1 s; 1 CPU and 1 GiB requested. Slurm accounting is disabled, so peak RSS is unavailable.
- Toolchain: Icarus 13.0 devel (cc25756d1), pinned `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`; binary hashes are in `raw-slurm-3749/results/toolchain.txt`.
- Editions: `-g2017` and `-g2023`; S cases also used `-gassertions`. Each compile/run has a 30-second GNU timeout.
- Exact per-case rc, raw stdout/stderr, SHA-256 and scheduler state are retained under `raw-slurm-3749/`.

| Probe | Paired observation |
|---|---|
| D1 | Compile/run rc 0/0; one drive to `3` at t=15; no intermediate `5`. |
| D2 | Compile/run rc 0/0; starts `z` at t=0, then `3` at t=15. |
| D3 | Compile/run rc 0/0; only the last between-event write (`2`) appears at t=15. |
| D4 | Compile rc 2. This first source omitted `default` from its clocking block; it is a probe setup error, not a simulator result. Corrected follow-up is pending. |
| D5 | Compile/run rc 0/0; `1` at t=5, `0` at t=10, `1` at t=25. |
| D6 | Compile/run rc 0/0; `1` at t=5, `0` at t=10, `1` at t=15. |
| D7 | Compile/run rc 0/0; `w=0,1,x,1` at t=1,6,16,26. |
| D8 | Compile/run rc 0/0; procedural write gives `55` at t=7 and t=16; clockvar write gives `aa` at t=25. |
| N7a–c | All compile rc 0 without diagnostics in both editions: continuous assignment, primitive, and procedural-continuous assignment to a variable associated with an output clockvar. No run is needed for these expected compile errors. |
| S1 / S2 / S5 | Each compile/run rc 0/0 and emitted exactly one `FAIL 25` in both editions. |
| S3a–c | Compile rc 2 in both editions because the initial control sources omitted the required semicolon after the pass action. This was a probe syntax error; these results do not test default sampled values. |
| S4 | Compile/run rc 0/0; emitted `S4 x=1` at t=5 in both editions. §4.4.2.6 puts concurrent assertion action-block code in Reactive; the exact short quote and PDF page references are in the Clause 16 evidence directory. |
| S6 | Compile rc 3 in both editions; `const'(cnt)` inside a property failed parsing. An ordinary-expression cast control is pending to isolate scope. |

Open+closed dedupe: 412 issues (285 open, 127 closed). Search results and existing-issue distinctions are in `DEDUPE.md` and `dedupe-all-issues.json`. No issue has been filed yet for this tranche; the lead will classify after the corrected follow-up.

## Run 2 — Slurm job 3750 (corrected control attempt)

The corrected D4 compiles/runs in both editions and prints `5 v=1`, `25 v=4`; values 2 and 3 do not appear. S3a/b compile and run with no failure output; S3c confirms `EDGE 0`, but without a cover action that run does not prove that the concurrent assertion attempt was evaluated, so the default-sample outcomes remain inconclusive. The compiler rejects `const'(cnt)` both inside a property and in a system-task argument outside a property. S7's correctly terminated pass action compiles/runs and prints `PASS` at t=5,15,25,35,45 in both editions. Full outputs are in the sibling `followup-d4-and-c16-controls-20261021/raw-slurm-3750/` directory.

The Slurm output and result files were available after job 3750 left the queue, but the controller had already purged its job record (`scontrol`: invalid job id; `sacct`: accounting disabled). Resource use was 1 CPU/1 GiB as requested; scheduler exit and runtime are therefore not asserted here.

After these paired results the lead filed one new §14.16.2 issue, [#909](https://github.com/dsellerbrock/iverilog-uvm/issues/909), for N7a–N7c. The source restriction and dedupe are recorded in `DEDUPE.md`. No Clause 16 issue is filed yet.

## Run 3 — Slurm job 3751 (final follow-up)

The final paired run staged 9 sources and produced all 18 edition/status rows with no timeout. Per-case status, raw logs, tool hashes and source hashes are under `followup-final-s3c-cover-20261021/`. The run requested 1 CPU and 1 GiB. The job had left the controller before `scontrol` lookup and accounting is disabled, so scheduler exit/runtime are unavailable; the generated status and raw outputs are preserved.

| Probe | Paired observation |
|---|---|
| D4 | Compile/run rc 0/0; `5 v=1`, `25 v=4`; no 2 or 3 appears. |
| S3a / S3b | Compile/run rc 0/0 with no FAIL at t=0. |
| S3c | The clock monitor prints `EDGE 0`; the cover-property match counter counts the t=0 match, but Icarus warns that the cover pass action is dropped for this recorded corner, so there is no `COVER` print. The matched initialized control does not fail. |
| S6 property / direct control / assignment control | `const'(cnt)` fails parsing in the property (compile rc 3), in a system-task argument, and in assignment (both outside-property controls compile rc 2). The ordinary `int'(cnt)` control compiles/runs and prints `int=2` in each edition. |
| S7 | Compile/run rc 0/0; pass action prints `S7 PASS` at t=5,15,25,35,45 in both editions. |

The lead has the paired result summary and raw per-case rc values for final §16 classification. The existing issue #909 remains the only new issue filed in this tranche so far.

# Clause 23.10 parameter probe results — Slurm job 3777

Pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP; 1 CPU/1 GiB. Job completed with exit 0:0. The harness ran each case under `-g2017` and `-g2023`, with 30-second per-process timeouts. Raw result rows, compile/run logs, version output, staged hashes, and `scontrol` record are under `raw-slurm-3777/`.

The intern's log summary was independently checked against `results.tsv`, stdout files, and Q7b's raw compiler diagnostics. The version banner also reports stale default paths under an older Slurm run directory; this harness explicitly used `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`, whose `ivl` and `ivlpp` were present. All cases reached their reported compiler/run outcomes through that explicit shared-toolchain path.

| Case | `-g2017` | `-g2023` | Lead classification |
|---|---|---|---|
| Q1 typed and untyped `defparam` override (§23.10.1) | `r1 is 3.000000 r2 is 3.141500` | same | Matches the standard example. |
| Q2 `defparam` across generate-block instances (§23.10.1) | Compile succeeds | same | PARTIAL — #928 |
| Q3 ordered assignment skips `localparam` (§23.10.2.1) | `12 16 4096` | same | Matches the standard example. |
| Q4a empty named assignment (§23.10.2.2) | `5 9` | same | Empty `.P()` keeps its default. |
| Q4b duplicate named assignment (§23.10.2.2) | Compile succeeds | same | PARTIAL — #929 |
| Q5 dependent value parameter (§23.10.3) | `2 0 4 4` | same | Matches the standard after correcting the harness's initial expected output. Raw job-3777 row says `OUTPUT_MISMATCH` only because it expected `2 4 4 4`; the declared 2-bit range truncates 4 to 0. |
| Q6 dependent type parameter (§23.10.3) | `32 7 16 7` | same | Recomputed value parameter type and width match. |
| Q7a default class type overridden to `int` (§23.10.3) | `4` | same | Matches the legal specialization. |
| Q7b default class type not overridden (§23.10.3) | Compiler aborts with internal error and assertion at `net_design.cc:2100` | same | PARTIAL — #931; source must fail elaboration, but the compiler aborts rather than reporting an error. |
| Q8 early-resolution collision (§23.10.4.2) | Compile succeeds | same | PARTIAL — #930; exact standard example is accepted although the standard requires an error. |

Q2/Q4b/Q8 and Q7b were compiled only because the harness treats their nonzero compile as the expected result class. The raw diagnostics show that Q2/Q4b/Q8 were accepted and Q7b aborted; no simulation result is claimed for those four cases.

The lead filed #928–#931 after reviewing the fresh open+closed dedupe. Final matrix statuses: §23.10.1 PARTIAL, §23.10.2.1 IMPLEMENTED (tested subset), §23.10.2.2 PARTIAL, §23.10.3 PARTIAL, §23.10.4.2 PARTIAL. Counts for this parameter tranche: four new issues, all in Clause 23.

# Result: §15.5.3 scope reducers

Slurm job 3386 completed with exit code 0 on exact current main `cc25756d187314742d347267c2a513b3e640a7fb`. Both probes were compile-only, under `-g2017` and `-g2023`, each with a 20-second process-group timeout.

| Edition | Probe | Compile rc | First diagnostic |
|---|---|---:|---|
| 2017 | `ev_formal_only.sv` | 2 | `syntax error` at line 1 |
| 2017 | `ev_call_fork_only.sv` | 0 | — |
| 2023 | `ev_formal_only.sv` | 2 | `syntax error` at line 1 |
| 2023 | `ev_call_fork_only.sv` | 0 | — |

The standard-form `task trigger(event ev); -> ev; endtask` is independently rejected, while a normal `input int` task call inside a fork compiles. This confirms the event-typed task formal is the failing construct in #829; no fork-call failure is implicated. Raw logs, compiled controls, input checksums, and the job output are preserved here.

## Open/closed issue dedupe (2026-10-20)

Searched all repository issues in both states for `event formal`, `event argument`, `task trigger(event`, and `formal` near `event`. No existing issue covers an event-typed task formal. Related results are distinct: open #699 covers event-handle assignment/comparison/null reclamation (§15.5.5); closed #439 covers explicit `triggered()` calls; closed #441 covers `wait_order`; closed #440 covers merged-event trigger semantics. These do not cover the §15.5.3 task-formal syntax failure.

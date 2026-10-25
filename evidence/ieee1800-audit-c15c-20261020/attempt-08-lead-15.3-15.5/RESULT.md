# Result: lead-directed §15 probe set

Slurm job 3384 completed with exit code 0 on DAN-DESKTOP (1 CPU, 1 GiB, 1 second). Slurm accounting is disabled; `scontrol show jobid 3384` reported `COMPLETED`, `ExitCode=0:0`. The exact-main compiler was Icarus 13.0-devel from `cc25756d187314742d347267c2a513b3e640a7fb`.

The job compiled and ran the requested tests under both `-g2017` and `-g2023`, with a 20-second timeout on every compiler and simulator process.

| Edition | Probe | Compile | Run | Result |
|---|---|---:|---:|---|
| 2017 | `p15_03a_semaphore.sv` | 0 | 0 | `RESULT pass=5 fail=0` |
| 2017 | `p15_05a_events.sv` | 4 | — | Parser rejects syntax at line 9 and event-typed task formal at line 23; no run |
| 2017 | `r15_wait_order_fail.sv` | 0 | 0 | Emits the out-of-order `ERROR`, then continues to `SURVIVED` |
| 2023 | `p15_03a_semaphore.sv` | 0 | 0 | `RESULT pass=5 fail=0` |
| 2023 | `p15_05a_events.sv` | 4 | — | Parser rejects syntax at line 9 and event-typed task formal at line 23; no run |
| 2023 | `r15_wait_order_fail.sv` | 0 | 0 | Emits the out-of-order `ERROR`, then continues to `SURVIVED` |

The raw compiler/simulator logs, generated `.vvp` files, result table, exact commands, and input checksums are preserved beside this file. Event-task syntax and `wait_order` error termination are awaiting lead review and open/closed issue dedupe; no issue or matrix status was changed in this attempt.

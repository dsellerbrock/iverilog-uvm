# Clause 23.11 bind results

Slurm job 3761 on DAN-DESKTOP used Icarus 13.0 devel `cc25756d1`, pinned at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, with `-B`, `-g2017`, `-g2023`, and `-gassertions`. The job requested 1 CPU and 1 GiB; each compile and simulation had a 30-second timeout. Raw compile/run logs, status, hashes, toolchain version, and the scheduler snapshot are under [`raw-slurm-3761/`](raw-slurm-3761/).

| Case | `-g2017` | `-g2023` | Observed behavior |
|---|---|---|---|
| B1 design-wide `bind dut` | compile/run 0/0 | 0/0 | Bound monitor appears under `top.u1.m` and `top.u2.m` at t=5,15,25 with `u1` values 3,F,F and `u2` values 5,5,5. |
| B2 target type plus explicit instance list | 0/0 | 0/0 | Only `top.u1.m` appears, with values 3,F,F at t=5,15,25. |
| B3 direct `top.u2` instance target | 0/0 | 0/0 | Only `top.u2.m` appears, with value 5 at t=5,15,25. |
| B4 target internal signal `q` | 0/0 | 0/0 | Both target instances are observed: `x` at t=5, prior registered value at t=15, and current value at t=25, matching Active-before-NBA scheduling. |
| B5 bound module containing assertion | 0/0 | 0/0 | Only the `u1` binding reports failures, at t=15 and t=25. |
| B6 bound parameter override | 0/0 | 0/0 | Both bound instances display `W=7`; values and target paths match B1. |
| B7 bind directive declared inside `top` | 0/0 | 0/0 | Both `dut` instances receive the monitor, with B1's values and times. |
| B8 interface instance into interface target | 0/0 | 0/0 | `top.bus.im` displays value 9 at t=5 and t=15. |
| NB module instance into interface target | compile 1 | compile 1 | Required error: a module cannot be bound into interface `bus_if`; an interface target requires an interface or checker instantiation. |

The paired runs agree across editions. The relative order of displays from separate bound instances at one edge is not used as an oracle. IEEE 1800-2017 §23.11 / Syntax 23-9 (printed pp. 738–740) and IEEE 1800-2023 §23.11 / Syntax 23-9 (printed pp. 771–772) require an interface or checker instantiation when the bind target is an interface; footnote 4 was reworded in 2023 without changing this rule. NB produces the required compile error in both editions. The standards also define `$unit` and wildcard-import visibility rules; those are not probed here. The audit lead classified the tested subset IMPLEMENTED, with no new issue. The existing §23.11 checker probe remains in the matrix row.

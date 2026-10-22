# Clause 25.9 virtual-interface depth results

Slurm job 3762 on DAN-DESKTOP used Icarus 13.0 devel `cc25756d1`, pinned at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`, with `-B`, `-g2017`, `-g2023`, and `-gassertions`. The job requested 1 CPU and 1 GiB; every compile and simulation had a 30-second timeout. Slurm reports `COMPLETED`, `ExitCode=0:0`. Raw logs, status, toolchain hashes and source hashes are under [`raw-slurm-3762/`](raw-slurm-3762/).

| Case | `-g2017` | `-g2023` | Observed behavior |
|---|---|---|---|
| V1 matching parameter value | compile/run 0/0 | 0/0 | Assigning `pif#(8)` to `virtual pif#(8)` succeeds; `$bits(v8.d)` prints 8. |
| V2 mismatched parameter value | compile 1 | compile 1 | Required assignment-compatibility error for `pif#(4)` to `virtual pif#(8)`. |
| V3 unselected interface to modport VIF | 0/0 | 0/0 | Assignment and write through the selected `drv` modport succeed; prints 1. |
| V5 class array of interface transactors | 0/0 | 0/0 | Constructor stores the two distinct virtual interfaces; `t[1].request()` changes only `s[1].req`, printing `1 x`. |
| V7 class-held VIF task call | 0/0 | 0/0 | Task call through the virtual interface changes `data`; prints `5a`. |
| V8a virtual interface as module port | compile 1 | compile 1 | Required §25.9 port-use error. |
| V8b virtual interface as union member | compile 1 | compile 1 | Required §25.9 union-member error. |
| V9 outside hierarchical reference in interface type | compile/run 0/0 | 0/0 | The interface containing `assign x = top.g` can be declared as a virtual interface and reads `1`; §25.9 requires this declaration to be illegal. |
| V10 external `defparam` instance assigned to VIF | compile 1 | compile 1 | Assignment is rejected with the assignment-compatibility diagnostic. |
| V12 class method event control through modport VIF | 0/0 | 0/0 | Procedural `wait (vif.b == 1)` wakes at t=7 and prints `woke 7`. |

The paired editions agree in every case. V9 is the only observed mismatch: the compiler accepts and executes a virtual-interface declaration whose interface contains an outside hierarchical reference, contrary to IEEE 1800-2017 §25.9 p. 769 and IEEE 1800-2023 §25.9 p. 801. The lead confirmed the same requirement in both editions and filed [#921](https://github.com/dsellerbrock/iverilog-uvm/issues/921). Its cited rule is: “it shall be illegal to use an interface containing those references in the declaration of a virtual interface.”

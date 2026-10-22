# §8.27 parameterized forward class typedef, corrected run

The first harness selected a module named after the probe, but this exact §8.27 example declares `module top`. This run corrects only the elaboration root to `-s top`; it tests the unchanged probe under both editions.

Expected stdout under each edition: `FP 1 2 64`.

Pinned compiler: `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/{iverilog,vvp}`. Slurm resources: 1 CPU, 1 GiB, 10 minutes; each compile/run has a 30-second timeout.

## Archive integrity

- `results-3506.tar.gz`: 2601 bytes; SHA-256 `e00766c339cbae74d29466755759c6935c7ca704013ff834c5af02a81c963263`.

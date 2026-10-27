# Corrected §23.3.3.7.1 interconnect probe — Slurm job 3776

Pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP, 1 CPU/1 GiB. The input matches the standard's `netlist` / `dut1(inout wire)` / `dut2(inout wand)` example, with only the requested `dut1` output display; no code reads `interconnect iwire` except module port connections.

- `-g2017`: compile/run 0/0, stdout `0`, no compile/runtime diagnostics.
- `-g2023`: compile/run 0/0, stdout `0`, no compile/runtime diagnostics.

The standard says that a connection involving interconnect merges nets, and if only one side is interconnect the merged net uses the other net's type. Its `wire`/`wand` example expects `0` because the merged net is `wand`. This corrected probe matches both editions' example.

Raw logs, results, scheduler record and remote hashes are under `raw-slurm-3776/`. The initial K5 source from job 3775 remains in attempt 03 and is explicitly marked invalid; it is not conformance evidence.

# IEEE 1800 clause 19 probe batch B — corrected bisections

Slurm job 2261 on DAN-DESKTOP, 1 CPU, 1 GiB; Icarus 13.0 devel from source/toolchain revision `9b5fad2af`. Script exit 1 because the required probes exposed gaps; see `results/combined.txt` for raw output and per-case logs.

- With an explicit coverpoint name, instance `get_inst_coverage()` compiles and returns 50.0% in both editions.
- Type `get_coverage()` on the covergroup and coverpoint fails elaboration in both editions (`No function named ...`).
- An embedded covergroup event tied to a local member compiles with “Failed to evaluate event expression `m_z` (event skipped)”. It records the first bin (50%) but does not record the second bin after the next member change.
- Assigning an embedded covergroup variable from a non-`new` method compiles and runs in both editions; coverage changes from 50% before re-assignment to 0% after. §19.4 says this variable may only be assigned in `new`.

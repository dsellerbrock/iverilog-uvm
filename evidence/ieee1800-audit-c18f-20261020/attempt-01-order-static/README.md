# §18.5.10 variable ordering and §18.5.11 static constraints

Lead-directed probes. In 2023 these features are §18.5.9 and §18.5.10. The source tests the standard's `s -> d == 0` distribution example with and without `solve s before d`, then tests static `constraint_mode()` propagation across instances and an ordinary nonstatic control. A separate edition-sensitive source tests real-valued solve ordering, allowed by 2023 §18.5.9 and disallowed by 2017 §18.5.10.

Compile and runtime processes use 30-second timeouts. Negative controls check restrictions on `randc`, non-rand and cyclic solve ordering, and matching `static` qualification on an external constraint prototype and definition. The Slurm script uses the pinned current-main toolchain at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/`.

No issue is filed from this tranche until results are reviewed, exact open/closed dedupe is recorded, and the audit lead classifies each failure.

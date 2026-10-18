Clause: IEEE 1800-2017/2023 §19.8.

Requirement: `get_coverage()` is available as a static method on covergroup and coverpoint types as well as on instances.

Probe: `evidence/ieee1800-audit-c19b-20261017/attempt-03/input/p19_08_type_methods.sv`, compiled with `-g2017` and `-g2023` using Icarus 13.0 devel at source `9b5fad2af`. Raw output: `evidence/ieee1800-audit-c19b-20261017/attempt-03/results/combined.txt`.

Observed: both editions fail elaboration with `No function named cg.get_coverage` and `No function named cg.cp_v.get_coverage`.

Expected: both type-level methods compile and return coverage for their respective type.

Clause: IEEE 1800-2017 §19.4 (p. 557) / IEEE 1800-2023 §19.4 (p. 579).

Requirement: “An embedded covergroup variable may only be assigned in the new method.”

Probe: `evidence/ieee1800-audit-c19b-20261017/attempt-03/input/p19_04_assignment_exec.sv`, compiled/run with `-g2017` and `-g2023` using Icarus 13.0 devel at source `9b5fad2af`. Raw output: `evidence/ieee1800-audit-c19b-20261017/attempt-03/results/combined.txt`.

Observed: assignment from method `f()` outside the class constructor compiles and executes in both editions. Coverage changes from 50% before reassignment to 0% afterward.

Expected: assignment of an embedded covergroup variable outside `new` is rejected.

# Clause 14.16.2 multi-driver depth probes

Scope: IEEE 1800-2017 and 1800-2023 §14.16.2. The matching clause has the same requirements in both editions (2017 printed pp.351–353; 2023 printed pp.370–371).

D1–D8 probe last assignment within a Re-NBA, net clockvar initialization and resolution, updates between clocking events, cycle-delayed drives, multiple clocking blocks driving one variable, edge clocking, and an ordinary procedural write followed by a clockvar write. N7a–N7c check the required compile-time rejection of continuous assignment, primitive, and procedural-continuous writes to a variable associated with an output clockvar.

Targets are scalar or packed, so these cases do not overlap #674's unpacked-net targets or #438's fixed-unpacked variable targets. The Re-NBA glitch example and NBA-versus-clockvar ordering remain untested.

Before the run, the status matrix had no §16.5, §16.5.1, or §16.5.2 rows. The paired results and exact commands are in RESULT.md; raw output, return codes, source/tool hashes, and scheduler lookups are in the corresponding `raw-slurm-*` directories. Because the initial D4 omitted a default clocking block, it was corrected and rerun. The lead filed [#909](https://github.com/dsellerbrock/iverilog-uvm/issues/909) for N7a–c; #674 remains the separate unpacked-net issue.

# Clause 16.16 N3 binding and multiclock follow-up

Lead-selected paired probes distinguish named-property operand binding, procedural assertion context, property evaluation, and the §16.16 rule (c) multiclock diagnostic. Each source is independent. Both `-g2017` and `-g2023` run with assertions enabled and the pinned Icarus toolchain; compile and simulation processes have 30-second limits.

The decisive controls are N3a (named property as an operand in a procedural assertion), N3d (same operand in a module-level assertion with an explicit event), and N3b (the named property is reached and must report its expected failures at 60 and 70). N3c retains the original standard-illegal inferred-clock/multiclock case.

Slurm job 3757 completed; results and raw scheduler/compiler evidence are in [`RESULT.md`](RESULT.md) and `raw-slurm-3757/`. The full open/closed issue snapshot and dedupe analysis are in [`DEDUPE.md`](DEDUPE.md). The audit lead classified the operand-binding gap and filed [#918](https://github.com/dsellerbrock/iverilog-uvm/issues/918).

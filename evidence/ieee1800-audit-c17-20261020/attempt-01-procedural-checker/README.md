# Clause 17.3 procedural checker instance probe

Test whether a checker instance in a module `initial` procedure is accepted and executes its clocked assertion in `-g2017` and `-g2023`. The existing `sv_checker_basic.v` static-instance test is the positive control.

- Probe source: `input/p17_03_procedural_checker_instance.sv`
- Standard basis: `STANDARD.md`
- Commands and toolchain: `run.sbatch`

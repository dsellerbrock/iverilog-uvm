# IEEE 1800 §18.6 randomization-method audit — 2026-10-17

This is one probe unit for IEEE 1800-2017 §§18.6.1–18.6.3 (pp. 528–530)
and IEEE 1800-2023 §§18.6.1–18.6.3 (pp. 550–551). The lead reports the
relevant text is unchanged between editions. The probes are deliberately
scoped; they do not claim all of clause 18.

## Probe coverage

`p18_06_methods.sv` checks successful `randomize()` and constraints, virtual
randomize through a base handle, inherited callbacks and overrides without
`super`, failed-randomize rollback and post-hook suppression, callbacks on an
enabled rand object member, skipping non-rand and rand-mode-disabled members,
and shared static-rand state. `neg/n18_06_override_randomize.sv` attempts to
override the built-in `randomize()` method.

Both probes run under `-g2017` and `-g2023`; each compile and simulation has a
wall-clock timeout. The run script and Slurm build script are in this directory.
Raw results and tool provenance will be added here after the run.

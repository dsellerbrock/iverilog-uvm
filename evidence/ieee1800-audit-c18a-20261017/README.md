# IEEE 1800 §18.6.1–18.6.3 randomization-method audit — 2026-10-17

This is the first probe unit for IEEE 1800-2017 §§18.6.1–18.6.3 (pp. 528–530)
and IEEE 1800-2023 §§18.6.1–18.6.3 (pp. 550–551). The lead reports the
relevant text is unchanged between editions. Supplementary cases are recorded
in [c18b](../ieee1800-audit-c18b-20261017/README.md).

## Probe coverage

`p18_06_methods.sv` checks successful `randomize()` and constraints, virtual
randomize through a base handle, inherited callbacks and overrides without
`super`, failed-randomize rollback and post-hook suppression, callbacks on an
enabled rand object member, skipping non-rand and rand-mode-disabled members,
and shared static-rand state. `neg/n18_06_override_randomize.sv` attempts to
override the built-in `randomize()` method.

Both probes run under `-g2017` and `-g2023`; each compile and simulation has a
wall-clock timeout. Slurm job 2243 built source commit `9b5fad2af` on
DAN-DESKTOP (`Linux x86_64`, WSL2) and completed with `script_exit=0`. The
positive probe printed all nine PASS lines and `DONE fails=0` in each edition;
the override-negative probe was rejected in each edition with the built-in
randomize diagnostic.

Raw output, compile/run logs, version strings, and binary hashes are in
[`results/`](results/). The iverilog and vvp SHA256 values are respectively
`f3368b253c7b5c7219a7891a2e21038626a2b4b1a97c96a9f8628b4732ae1315` and
`1e6ccd74afb86d2e4783d6683772919b76156177717808b9cc8889da0b5f7d70`.

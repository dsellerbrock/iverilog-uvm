# IEEE 1800 §16.8 assertion-enabled confirmation

Slurm job 3177 repeated all §16.8 probes with the project's explicit
`-gassertions` option, using Icarus 13.0 devel built from source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; VVP
SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`).
Each compile and runtime invocation was capped at 120 seconds.

In both `-g2017` and `-g2023`, the basic named sequence and the isolated
untyped-formal sequence compile and run `PASSED`. The typed `logic` formal and
typed default formal are rejected with syntax errors. The mismatched
`endsequence` label compiles with exit 0 despite §9.3.4 requiring a matching
block name. Raw per-edition results and the Slurm transcript are preserved in
`results/` and `logs/`.

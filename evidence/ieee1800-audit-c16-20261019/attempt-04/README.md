# IEEE 1800 Clause 16.8 sequence-declaration probes

IEEE 1800-2017/2023 §16.8 Syntax 16-5 covers named sequence declarations,
formal arguments, optional defaults, and optional `endsequence` labels. IEEE
1800-2017/2023 §9.3.4 says a mismatched closing block name is an error and
explicitly includes `endsequence` among the applicable end keywords.

Slurm job 3174 used Icarus 13.0 devel built from source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; VVP
SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`).
It tested `-g2017` and `-g2023` with a 120-second timeout per compiler and
simulation invocation.

Results in both editions:

- `p16_08_sequence_basic.sv` compiles and runs `PASSED`; its named declaration
  has a matching closing label.
- `p16_08_sequence_args.sv`, which combines untyped and typed formals, is
  rejected at the typed `logic` formal on line 11. Because the compilation
  fails, this combined source alone does not establish untyped-formal support.
- `p16_08_sequence_default.sv` is rejected at its typed default formal on line 7.
- `n16_08_end_label_mismatch.sv` compiles with exit 0 despite its mismatched
  `endsequence` label.

The isolated untyped-formal follow-up and its passing result are in
[`../attempt-05-untyped-args/`](../attempt-05-untyped-args/). Raw outputs,
compiler identity, and the Slurm transcript are under `results/` and `logs/`.

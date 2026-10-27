# IEEE 1800 §10.3–§10.6 probes

Run on 2026-10-19 on macOS Darwin ARM64 with `~/codex-supervisor/localrun`.
Checkout: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; Icarus 13.0-devel
SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
All reported outcomes match in `-g2017` and `-g2023`.

## Positive probes

- `p10_03a_cont_assign.sv`: continuous assignments, strengths, net declarations,
  vector direction, and multiple drivers; 14/14 checks pass.
- `p10_04a_proc_assign.sv`: blocking/nonblocking timing and assignments;
  9/9 checks pass. The first run timed out because a free-running clock had no
  `$finish`; the authorized runner-only correction adds `$finish` after the
  final result. Attempt-01's timed-out output is invalid; attempt-02 is the
  recorded result.
- `p10_06a_procont.sv`: procedural `assign`/`deassign`; 15/15 checks pass.
- `p10_06b_force_release.sv`: the §10.6.2 force/release example compiles and
  runs, but differs from the standard's expected trace: expected `d=0,1,0`
  at times 0, 10, 20; observed `d=x,1,x` in both editions. The compiler warns
  that a procedural continuous-assignment RHS is evaluated only once.

## Reduced §10.6 controls

- `r10_06a_assign_rhs_update.sv` and `r10_06a_force_release_assign.sv` show
  that a single-variable RHS and force/release path work (2/2 checks; `d`
  follows 0, 1, 0).
- `r10_06a_multi_rhs_update.sv` and `r10_06a_multi_rhs_staged.sv` isolate the
  discrepancy to a multi-operand RHS (`a & b & c`): both editions leave `d=x`
  after the operands settle to `1,0,1`, whether changed together or in stages.

## Negative probes

Under §10.3, the tests for variable initialization plus continuous assignment,
variable procedural plus continuous assignment, two continuous assignments
to a variable, high-impedance assignment, and interconnect assignment all
reject in both editions. Under §10.6.1/.2, the one-line negative probes
`neg/n10_06_assign_bitsel.sv` and `neg/n10_06_force_var_bitsel.sv` compile
silently in both editions, despite targeting variable bit-selects.

## Dedupe and run evidence

The nine all-state searches (open and closed issues) are in
`attempt-01/dedupe_*.json` (22 unique issue results). I reviewed #430, #432,
and closed #493; none covers these §10 behaviors. Full commands and
per-edition compiler/VVP output are in `attempt-01/` through `attempt-05/`.
`attempt-01` includes the discarded timeout; the corrected §10.4 rerun is in
`attempt-02/`. Localrun wall/RSS: attempt-01 128.60 s / 16,957,440 bytes
(including the discarded timeout); attempt-02 0.69 s / 16,875,520 bytes;
attempt-03 0.73 s / 16,957,440 bytes; attempt-04 0.76 s / 16,875,520 bytes;
attempt-05 0.59 s / 16,924,672 bytes.

The tech lead classified two uncovered §10.6 gaps after reviewing the probes
and all-state dedupe: stale evaluation of a multi-operand procedural
continuous-assignment RHS (#768), and acceptance of variable bit-select
targets for procedural `assign` and `force` (#769). Both issues are OPEN with
the `1800-audit` label. The two diagnostics share one issue because they
violate the same variable-target restriction in §§10.6.1/.2; the RHS behavior
is tracked separately. The lead could not execute GitHub CLI commands, so I
ran its exact classified issue drafts as the probe runner.

Standards checked: IEEE 1800-2017 §§10.3–10.6 (force/release example 2 in
§10.6.2, p. 243); IEEE 1800-2023 §§10.3–10.6.

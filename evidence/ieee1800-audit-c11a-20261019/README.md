# IEEE 1800 §11 operator audit, tranche A

Probes ran on macOS Darwin ARM64 under `~/codex-supervisor/localrun` on
2026-10-19. Checkout HEAD: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`;
built compiler source: `b9441bafbdb0b6b7413c09e0381845e69481391b`; Icarus
13.0-devel SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`;
VVP SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
All outcomes matched in `-g2017` and `-g2023`.

## §11.3.5–§11.3.6 and §11.4.1–§11.4.7

- `p11_04a_arith.sv`: 29/29 pass. Covers remainder, exponentiation, division,
  signed/unsigned sizing, X propagation, integer/real increment, compound
  assignment, one-time indexed lvalue evaluation, short-circuit side effects,
  and assignment-expression value/type.
- `p11_04b_compare.sv`: 23/23 pass. Covers signed/unsigned/real relational
  operations, precedence, equality and case equality, class-handle equality,
  wildcard matching, logical operators, implication/equivalence, and X/Z.
- `n11_03_assign_in_event.sv` rejects with rc=1; the diagnostic includes the
  synthetic `$ivl_assign_expr$=` name and an event-synthesis warning.
- `n11_03_assign_outside_proc.sv` rejects with rc=2; the diagnostic includes
  `$ivl_assign_expr$=` and an internal synthesis error. Both are rejected in
  both editions and recorded as low-priority diagnostic debt in DD-125.
- `n11_04_handle_relational.sv` rejects with `Class/null is not allowed with
  the '<' operator.` This is distinct from #608, which covers arithmetic on
  class handles and says relational use already rejects.

Logs and the runner are in `attempt-01/`. Command:
`~/codex-supervisor/localrun 300 bash evidence/ieee1800-audit-c11a-20261019/attempt-01/run-probes.sh`.
Wall/RSS: 1.76 s / 16,891,904 bytes.

## §11.3.1 Table 11-1 real operands

IEEE 1800-2017 Table 11-1 p.256 and 1800-2023 Table 11-1 p.271 agree that
`%`, `%=` and the listed bitwise/shift families accept integral operands only.
The reduction tests each compile both editions; accepted programs also ran:

- `n11_real_mod.sv`: `r % 2.0` compiles and runs, reporting
  `OUT q=1.500000 i=0 r=5.500000`.
- `n11_real_modassign.sv`: `r %= 2.0` compiles and runs, reporting
  `OUT q=0.000000 i=0 r=1.500000`.
- `n11_real_bitnot.sv`: compiler segfault, rc=139.
- `n11_real_shlassign.sv` and `n11_real_andassign.sv`: compiler assertion
  abort, rc=134, in `draw_stmt_assign_real_opcode`.
- `n11_real_ashl.sv`, `bitand`, `bitor`, `bitxor`, `redand`, `caseeq`,
  `wildeq`, `concat`, `shl`, and `shr` reject with rc=1.

Per-case compile/run output and the generation/run script are in `attempt-02/`.
Command: `~/codex-supervisor/localrun 300 bash evidence/ieee1800-audit-c11a-20261019/attempt-02/generate-and-run.sh`.
Wall/RSS: 5.51 s / 16,990,208 bytes. The lead classified the accepted operators and compiler aborts as two distinct
gaps: [#770](https://github.com/dsellerbrock/iverilog-uvm/issues/770) tracks
real `%` and `%=` acceptance; [#771](https://github.com/dsellerbrock/iverilog-uvm/issues/771)
tracks compiler crashes on `~r`, `r <<= 1`, and `r &= 1`. Both are OPEN with
the `1800-audit` label. The issue searches were all-state and found no exact
duplicates.

## §11.4.8–§11.4.11 bitwise, reduction, shift, and conditional operators

`tests/1800_audit/c11/p11_04c_bit_shift_cond.sv` passes 19/19 checks in both
editions. It covers four-state bitwise results, reduction identities and X
handling, logical/arithmetic shifts and signedness, unknown shift amounts,
ambiguous conditional merging, real and class-handle branches, and conditional
side effects. The first source attempt had no valid test result: `1'bx?` and
`1'bz?` were tokenized as based literals with an extra digit. Per the lead's
correction, whitespace was added around all five ternary operators; this changed
only token separation. Failed attempt-01 compiler logs are retained; corrected
pass output and runner are in
`evidence/ieee1800-audit-c11b-20261019/attempt-02/`. Localrun wall/RSS:
0.52 s / 16,859,136 bytes. All-state dedupe terms and results are in
`evidence/ieee1800-audit-c11b-20261019/attempt-01/`; only #770/#771 appeared,
and those cover real-operand restrictions rather than these normal operand
semantics.

## Dedupe

All searches used `gh issue list --state all --limit 40` (open and closed).
The five §11.3.1 terms were `real operand`, `real modulus`, `real shift`,
`real bitwise`, and `integral operator real`; their union found only #522,
a closed real-coverpoint expectation issue, which is unrelated. The ten
operator searches for tranche A and their raw JSON are stored in
`attempt-01/dedupe_*.json`. I inspected #469 and #473 (closed two-state
conversion/assignment-expression issues); neither covers these findings.
#608 covers arithmetic class-handle operators; its body states relational
handle use already rejects.

The audit ledger now totals 40 new issues: §11.3.1 added two this tranche.
The crash finding excludes `|=`, `^=`, `>>=`, `<<<=`, and `>>>=`, which were
not probed.

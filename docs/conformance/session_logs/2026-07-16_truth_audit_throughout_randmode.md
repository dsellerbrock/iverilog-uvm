# 2026-07-16 — Milestone truth audit + two reopened technical fixes

Directive: "Milestone Truth Audit and Corrective Implementation Pass."
Perform a constructively adversarial audit of M1–M13, correct overstated
"CLOSED" labels, then IMPLEMENT the highest-priority technical gaps —
documentation must support engineering, not replace it.

## Truth audit (see milestone_truth_audit_2026-07-16.md)

Re-classified every milestone against its manifesto-defined scope, with
the rule that a *recorded corner that was in the original scope does not
justify closure*. Headline corrections:

- **M9 "Core SVA engine" CLOSED → SUBSET COMPLETE** with an M9A–M9D
  split: the core is solid, but `intersect`/`throughout`/`within`/
  `until`/`until_with`/`nexttime`/`eventually`/`s_eventually` were loud
  sorries — sequence/property operators inside the SVA milestone.
- **M3 CLOSED → PARTIAL**: per-field `rand_mode(0)` silently no-ops
  (a frozen field is still randomized — a *silent* miscompile).
- **M10/M12/M13 CLOSED → SUBSET COMPLETE**: multidim open arrays +
  packed-vector marshaling + DPI export (M10); assertion VPI object
  model absent (M12); bind-to-instance, `$nochange`/`$timeskew`/
  `$fullskew`, config (M13) — all in scope, all unimplemented (loud).
- **M1 CLOSED → SUBSET COMPLETE (M1A)**: typed dispatch done; the
  broader semantic-IR migration (typed lvalue/aggregate interfaces,
  fallback-to-diagnostic conversion) not started.
- **M6 CLOSED → PARTIAL (M6B reopened)**: event-region mapping and
  invariant tooling incomplete.

Only two corrected gaps are *silent* (M3-rm, M4-av); the rest are loud
diagnostics (honest but incomplete). The two silent ones are the
highest-priority reopened items.

## Technical implementation 1 — M9C `throughout` (16.9.9)

`guard throughout seq` requires the boolean guard to hold at EVERY clock
tick from the start of seq until it completes, including the intermediate
wait cycles of a multi-cycle `##N` delay. Implemented by a source-level
transformation into an ordinary unit-delay sequence the existing
token-pipeline engine already handles exactly: guard is AND-ed into every
step's boolean, and each `##N` gap is expanded into N-1 intermediate unit
steps whose boolean is guard alone.

Exact for constant, bounded delays. Variable-window shapes (`##[m:n]`,
`##[m:$]`, `[*m:n]`) and non-duplicable guards are diagnosed loudly (the
assertion is dropped) — no silent approximation. `pform_sva_throughout`
in pform.cc reuses `sva_clone_expr_` + `PEBLogic`; the grammar rule
replaces the former `pform_sva_sorry`.

Adversarial test (`tests/m9c_throughout_test.sv`): the guard dropping at
the *intermediate wait cycle* of `##2` MUST fail — a naive "AND guard
into the booleans only" lowering would wrongly pass it. Negative test
(`tests/negative/m9c_throughout_range.sv`): range-window throughout is
diagnosed, not approximated.

## Technical implementation 2 — M3-rm per-field `rand_mode(0)` (18.8)

**Silent miscompile** (the directive's priority #1). `obj.field.rand_mode(0)`
was a no-op, so a rand field the user froze was still randomized —
potentially generating illegal stimulus with no diagnostic.

Root cause: `obj.field.rand_mode()` reaches `PCallTask::elaborate_usr`,
where `obj.field` resolves as a receiver and the general method dispatch
silently drops `.rand_mode()` on a non-class (bit-typed) receiver. The
runtime already tracks rand_mode per property (`cobj->rand_mode(pid)`,
consulted by the randomize opcodes); only an all-properties `%rand_mode`
opcode existed.

General fix (no UVM-specific branch):
- `elaborate.cc`: intercept `obj.field.rand_mode(mode)` at the top of
  `elaborate_usr`, before method dispatch. Resolve the object and the
  field's property index via `property_idx_from_name`, disambiguating
  from object-level `rand_mode` by requiring the second-to-last path
  component to be a real class property. Emit
  `$ivl_class_method$rand_mode` with a third `pid` argument.
- `tgt-vvp/vvp_process.c`: the 3-arg form emits `%rand_mode/p <pid>`;
  the 2-arg form keeps the all-properties `%rand_mode`.
- `vvp`: new `%rand_mode/p` opcode (`of_RAND_MODE_P`) sets rand_mode for
  the single property `pid` (opcode table kept sorted).

Adversarial test (`tests/m3rm_rand_mode_field_test.sv`): frozen field
unchanged across 40 randomize() calls, siblings change, re-enable
restores, object-level freeze holds all. Existing `simple_rand_test` /
`rand_mode_test` still pass.

## Regression evidence

- New focused tests: m9c_throughout PASS, m3rm_rand_mode_field PASS.
- SVA suites (m9_sva_engine, m9_sva_algebra, sva_*): PASS.
- Randomization suites (simple_rand, rand_mode): PASS.
- Negative suite: **24/24** (added m9c_throughout_range).
- UVM harness + ivtest name-diff: see promotion commit.

## Status of the two implemented items

- **M9C `throughout`**: **SUBSET COMPLETE** for `throughout`
  (constant-delay windows; variable-window loud-sorry). `within`/`until`/
  `intersect` remain (M9B/M9C open).
- **M3-rm**: **COMPLETE** — per-field and object-level `rand_mode` both
  correct; M3's silent gap closed. (Other M3 items unaffected.)

## Next engineering action

**M4-av** — string/real-VALUED integer-keyed associative-array reads are
still silently wrong (only the `obj`-key `sig`-load opcode exists). It is
the remaining silent miscompile and the highest-priority next target.

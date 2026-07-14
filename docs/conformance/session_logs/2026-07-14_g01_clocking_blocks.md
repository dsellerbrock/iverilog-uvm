# Session 2026-07-14i — G01/G02: clocking blocks outside interfaces + ##N cycle delays (M8 entry)

## Target

Gap-audit entry point for milestone M8 (clocking blocks): **G01** —
`clocking ... endclocking` in a module produced
`error: clocking declarations are only allowed in interfaces.` followed by
`assert: pform.cc:3874: failed assertion scope && scope->is_interface` and a
core dump. **G02** — the same crash for clocking inside program blocks.
IEEE 1800-2017 14.3 explicitly permits clocking blocks in modules,
interfaces, programs, and checkers.

Scope grew to the adjacent same-clause defects found while reducing:

1. `default clocking` declarations (named and anonymous) were **parsed and
   silently dropped** (a compile-progress fallback in parse.y), and the
   `default clocking existing_id;` reference form (A.1.4) did not parse.
2. Clause 14.4 skew syntax barely parsed: `#1step` did not lex, edge skews
   (`input negedge x;`) and `default input <skew> output <skew>;` items were
   syntax errors. `ref` was wrongly accepted as a clocking direction.
3. Procedural cycle delays (`##N;`, 14.11) did not lex at all — `##` was two
   `'#'` tokens and always a syntax error.
4. A latent crash: a duplicate clocking-block *name* left
   `pform_cur_clocking` null and the first clocking item then died on the
   `pform_add_clocking_signal` assertion.

## Root cause

Clocking blocks were implemented (Phase 13/55) only for the interface +
virtual-interface UVM path: `pform_start_clocking_block` asserted
`scope->is_interface`, and every elaboration-side resolver
(`resolve_interface_pform_clocking_event_`, the two path-rewrite helpers
duplicated across elab_expr.cc/elab_lval.cc) gated on `is_interface()`. The
grammar's non-interface branch still called `pform_start_clocking_block`
after issuing the error → assertion → abort.

## Implementation

The existing clocking model **aliases** `cb.sig` to the underlying signal
(no sample/drive skew semantics yet — that is the next M8 increment; the
audit records the approximation). This session makes the model
scope-complete and consistent, not deeper.

- **pform.cc / pform.h**: `pform_start_clocking_block` accepts any
  module/interface/program scope (14.3); gains `is_default` (registers the
  scope's default clocking, errors on a second default per 14.12) and a null
  name for the anonymous default form (registered under the internal name
  `$default_clocking`, unreachable from source). New
  `pform_set_default_clocking_ref` for `default clocking id;`; existence is
  validated in `pform_endmodule` so declaration order doesn't matter.
  `pform_add_clocking_signal` now tolerates a failed block open (fixes the
  duplicate-name crash). `Module` gains `perm_string default_clocking`.

- **parse.y**: `clocking_declaration` no longer errors outside interfaces;
  the two `default clocking` declaration forms now register their blocks
  (fallback removed) and the reference form is new. `clocking_item` was
  rewritten to the A.6.11 shape: `input|output [clocking_skew]`,
  `input [skew] output [skew]`, `inout` (no skew, and no `ref`, per LRM),
  and the three `default` skew items. New `clocking_skew` nonterminal:
  `edge_identifier [delay_control] | delay_control`, with `#1step`,
  `#(expr)`, `#value` and `posedge/negedge/edge` forms. Skews are accepted
  and discarded (alias model). **Bison conflicts went down**: 459→458 s/r,
  1060→1053 r/r (the old `port_direction '#' expression` rule was the
  conflicting one); all three "useless rule" warnings are pre-existing.

- **lexor.lex**: `1step` (5.8) and `##` (14.11) tokens, both
  SystemVerilog-gated with REJECT fallback — neither sequence was lexable
  before, so no legacy behavior changes.

- **netmisc.cc / netmisc.h**: the two clocking path-rewrite helpers that
  were *duplicated* as statics in elab_expr.cc and elab_lval.cc are now
  shared functions (debt reduction):
  `rewrite_class_clocking_member_path` (virtual-interface receivers,
  unchanged logic) and `rewrite_clocking_member_path_via_scope`
  (generalized: any instance scope — interface, module, or program). New
  `rewrite_enclosing_scope_clocking_member_path` resolves **same-scope**
  `cb.sig` references (leading path component names a clocking block of an
  enclosing MODULE-type scope) — this is what module/program-scope clocking
  and clocking inside interface task bodies need. Wired into both l-value
  and expression elaboration plus the two compile-progress rescue sites,
  guarded on `!sr.net` so real symbol resolutions always win.

- **elaborate.cc**: `resolve_interface_pform_clocking_event_` →
  `resolve_scope_pform_clocking_event_` (drops both `is_interface` gates)
  so `@(inst.cb)` works for module/program instances. The Phase 55
  same-scope `@(cb)` walker already worked for any MODULE-type scope.

- **##N cycle delay (14.11)**: new `PCycleDelay` statement
  (Statement.h/.cc, elab_scope.cc, elab_sig.cc, pform_dump.cc). Grammar:
  `## delay_value_simple [stmt]` and `## ( expression ) [stmt]` (A.6.11
  forms: number, identifier, parenthesized expression). Elaboration finds
  the nearest enclosing scope with a `default_clocking` (walks NetScope
  chain → pform_modules) and lowers to `repeat (count) @(<cb name>) ;` —
  the synthesized `@(name)` resolves through the SAME Phase 55 machinery as
  source-level `@(cb)`, so the underlying event expression is picked up
  from the block declaration and resolved in the referencing scope. No
  default clocking in scope → clause-referenced error.

## What deliberately did NOT change

- No skew *semantics*: `cb.sig` remains a direct alias (input sampling at
  1step/Observed, synchronous output drives in Re-NBA, and `cb.sig <= ##N v`
  intra-assignment cycle delays are the next M8 increment — the M6
  Preponed/Observed entry points are the landing spot).
- No UVM-specific branches anywhere; all lookups are name/scope-driven.
- Interface clocking behavior is unchanged (regressions byte-identical).

## Tests added

- `tests/g01_module_clocking_test.sv` — module-scope clocking (@(cb) wait,
  input read, output drive), every A.6.11 skew item form, named default
  clocking used by name, reference form, hierarchical `@(sub.cb)` +
  `sub.cb.sig`, program-block clocking with drive (G02), multiple blocks
  coexisting.
- `tests/g01_cycle_delay_test.sv` — ##0/##1/##2, statement form,
  `##(expr)`, `##identifier`, cycle delay inside a task body.
- `tests/negative/g01_cycle_delay_no_default.sv`,
  `g01_multiple_default_clocking.sv`, `g01_undeclared_default_clocking.sv`.

## Regressions (final build, quiet machine)

- UVM `.github/uvm_test.sh`: **129/129** (127 baseline + 2 new tests) —
  see commit message for the exact tail.
- ivtest `vvp_reg.pl`: **2961/3101 passed, 132 failed** with failure names
  **identical to the same-machine pristine-main baseline** (fresh baseline
  built from fb79080 in a worktree, diffed by name).
- ivtest `vvp_reg.py`: 284 ran / 12 failed (baseline-identical);
  `vpi_reg.pl`: 76/76 (baseline-identical).
- Negative suite: **9/9** (3 new).
- `tests/m6_region_trace/run_region_trace.sh`: PASS.
- Bison: 458 s/r + 1053 r/r (both LOWER than baseline 459/1060); flex clean.

## Gap audit deltas

- **G01 FIXED** (crash removed; module clocking functional under the alias
  model). **G02 FIXED** (program clocking functional).
- New capability: default clocking registration + procedural ##N.
- Remaining clause-14 tail (recorded for the next M8 increment): skew
  sampling/driving semantics; `cb.sig <= ##N v` synchronous drives with
  cycle delay; `clocking_decl_assign` (`input a = expr;`); `global
  clocking` (14.14); default clocking in generate scopes resolves to the
  enclosing module's block.

## Next engineering step

M8 increment 2 — real clocking semantics: input sampling (#1step via a
1-deep value/timestamp history on the sampled signal, matching the
Preponed-region value; #0 via `schedule_at_observed`) and synchronous
output drives (scheduled into Re-NBA via `schedule_at_observed`/re-nba
queues added in M6), replacing the alias rewrites for all scopes at once.
Entry: `rewrite_*_clocking_member_path*` call sites become typed
sample/drive lowerings; characterization tests first
(`g01_module_clocking_test` pins the alias behavior today).

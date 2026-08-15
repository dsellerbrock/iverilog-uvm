# 2026-08-14 — Chapter 20 coverage access and `$isunbounded`

## Starting evidence

The pinned `sv-tests` replay at
`evidence/sv-tests-c4229f3/full-all-uarray-slices-final-20260814T1234MDT/results.json`
classified these two positive tests as `ICARUS_REJECT_SLANG_ACCEPT_POSITIVE`:

- `chapter-20/20.6--isunbounded.sv`: Icarus rejected the symbolic unbounded
  parameter initializer `parameter int i = $`.
- `chapter-20/20.14--coverage.sv`: Icarus did not predefine the fifteen
  `SV_COV_*` macros and consequently reported nine compile errors.

Slang `11.0.415+8acc660a2` accepts both pinned sources with no errors or
warnings. The work was based on `9e2094f2913fef743552a4042185411e9f076a85`
and used only focused, resource-capped builds and tests.

## Symbolic unbounded parameters (6.20.2.1 and 20.6)

`$` now has a dedicated parse and netlist representation. It is never
converted into a large number or an X-valued integer. The grammar admits it
only in value-parameter initializers, ordered or named parameter overrides,
and direct call arguments. Semantic elaboration then permits the value only
for an integral value parameter or as the sole argument of `$isunbounded`.

The marker is preserved through direct parameter aliases and parameter
overrides. `$isunbounded` constant-folds to one for the literal, an unbounded
parameter, or an alias of one, and to zero for every ordinary constant or
run-time expression. Numeric use, selection, nonintegral parameter types,
value ranges, and wrong function arity are compile errors.

Keeping `$` out of the general expression primary is intentional: it avoids
ambiguity with queue/open-range syntax and prevents accidental acceptance as
an ordinary numeric value. A Bison comparison against the pristine base has
the same 535 shift/reduce and 1115 reduce/reduce totals and the same normalized
conflict profile; only state numbers move because of new deterministic states.

## Code-coverage access (40.3)

All fifteen constants from 40.3.1 are predefined, with their normative
values, when a SystemVerilog edition is selected. The five 40.3.2 functions
are registered as signed 32-bit functions and enforce their exact arity and
argument categories:

- `$coverage_control(control, type, scope, module-or-instance)`;
- `$coverage_get_max(type, scope, module-or-instance)`;
- `$coverage_get(type, scope, module-or-instance)`;
- `$coverage_merge(type, name)`;
- `$coverage_save(type, name)`.

The two related clause-19 database tasks, `$set_coverage_db_name(name)` and
`$load_coverage_db(name)`, now enforce one string argument as well. Integral
domain values, known bits, scope mode, coverage type, module instance, `$root`,
and module-definition strings are validated. Invalid run-time values return
`SV_COV_ERROR` with a diagnostic.

Icarus does not currently instrument assertion, FSM-state, statement, or
toggle code coverage and has no code-coverage database backend. The API
therefore reports the standard's unavailable-state values instead of fake
success:

- START, CHECK, queries, and save return `SV_COV_NOCOV` where 40.3 permits it;
- STOP, RESET, and merge return `SV_COV_ERROR`;
- every unavailable operation emits an explicit warning;
- the existing functional-coverage `$get_coverage()` service remains
  independent and unchanged.

## Permanent focused coverage

The legacy and JSON harnesses contain the same seven cases:

- `sv_ch20_isunbounded`: positive literal, typed/untyped parameters, aliases,
  named override, and ordinary-expression controls;
- `sv_ch20_isunbounded_use_fail`: one illegal arithmetic use;
- `sv_ch20_isunbounded_type_fail`: one illegal nonintegral parameter;
- `sv_ch20_isunbounded_arity_fail`: three malformed calls producing two
  compiler diagnostics after recovery;
- `sv_ch20_coverage`: all fifteen macros, every function/task, root/module/
  instance targets, exact unavailable statuses, and functional-coverage
  coexistence;
- `sv_ch20_coverage_bad_domain`: six invalid run-time domain/target values;
- `sv_ch20_coverage_call_fail`: seven exact function/task arity and type
  diagnostics.

Slang accepts the three positive-polarity sources and rejects the four
negative-polarity sources with respective diagnostic counts 1, 1, 2, and 7.
The installed focused Icarus run passes 7/7 in the legacy harness and 7/7 in
the JSON harness. Both pinned corpus sources compile; the `$isunbounded` case
prints `0` then `1` as asserted, while the coverage case exits normally with
an explicit warning for each unavailable operation.

The remaining boundary is real code-coverage instrumentation and database
load/save. This change supplies the standards-defined API, validation, and
honest unavailable results; it does not claim that backend.

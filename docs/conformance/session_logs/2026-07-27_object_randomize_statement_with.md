# Object `randomize() with` in statement position — 2026-07-27

## Confirmed defect

On current `main` (`2e5eab5d8`), legal object calls such as

```systemverilog
obj.randomize() with { x == expected; };
void'(obj.randomize() with { x == expected; });
```

failed during parsing. The older no-parentheses statement production
accepted `obj.randomize with {...};` but constructed a call without
retaining the constraint block, so that sibling could silently randomize
without enforcing the inline constraint.

This campaign is deliberately separate from the scope form
`std::randomize(vars) with {...}` (M3B-10).

## Root cause

Expression calls store inline constraints on `PECallFunction` and already
lower through the Z3-backed `make_randomize_with_expr` path. Statement
calls are represented by `PCallTask`; the statement grammar did not attach
brace-form constraints to that node, and statement elaboration only knew
the plain `%randomize` method path.

The explicit `this.randomize() with {...};` spelling also overlaps the
existing expression production through the closing brace. The statement
production intentionally shifts the following semicolon, which selects the
statement form; the permanent regression pins that decision.

## Implementation

- Brace-form statement productions retain the constraint expressions on
  `PCallTask`, including bare, explicit-void, explicit-`this`, and
  no-parentheses forms.
- `make_randomize_with_expr` now accepts the common call location,
  argument-selector list, and constraint list rather than depending on a
  `PECallFunction`.
- `PCallTask::elaborate_randomize_with_` invokes that shared builder and
  assigns the ignored success bit to a hidden temporary. Normal assignment
  elaboration therefore drives the same runtime `%randomize/with` path as
  an expression call.
- Both ordinary class receivers and method-call-result receivers dispatch
  through the helper. Bare calls retain the existing function-as-task
  warning; `void'(...)` suppresses it.

No runtime solver or object representation change was needed.

## Discriminating regression

`ivtest/ivltests/sv_object_randomize_statement_with.v` checks:

- direct and nested-property receivers;
- an indexed fixed array of class handles;
- a method-call-result receiver;
- explicit `this` and implicit current-object receivers;
- caller-scope and automatic-task-frame constraint values;
- inline variable control with an unlisted state variable;
- bare, no-parentheses, and explicit-void syntax;
- successful constraints and an unsatisfiable constraint;
- failed-call object preservation;
- `pre_randomize` on failure and suppression of `post_randomize`.

The pre-fix compiler rejects the statement forms with syntax errors. The
fixed compiler reaches every explicit PASS/FAIL check and prints `PASSED`.
Adjacent expression-form, inherited-soft, variable-control, and constraint
width tests remain clean.

## Validation

- parser generation: 495 shift/reduce and 1161 reduce/reduce conflicts; the
  one added shift is the explicit statement-vs-expression semicolon choice
  described above;
- `make check`: pass;
- focused clause-18 tests: pass;
- constraints/UVM subset: 22/22, real DPI;
- negative suite: 61/61;
- SVA legacy/NFA dual-run: 36/36;
- vendored ivtest name-diff: 3,218 total, exactly 44 expected failures,
  zero unexplained or stale identities;
- bundled VPI: 94/94;
- dedicated DPI subsystem: 20/20, real DPI, zero skips;
- full UVM: 226/226, real DPI, zero skips;
- installed and relocated `-uvm` frontend: all eight scenarios pass.

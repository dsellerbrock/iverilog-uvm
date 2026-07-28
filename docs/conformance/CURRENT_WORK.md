# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-27

Branch: `codex/object-randomize-statement-with`, based on current `main`
at `2e5eab5d8`. Draft PR: #126.

The object `randomize() with {...}` statement-position campaign is closed:

- bare, `void'(...)`, and no-parentheses statement calls retain their
  inline constraint block instead of rejecting it or dropping it;
- statement calls use the same Z3-backed builder as expression calls;
- variable selectors, caller-scope values, nested/indexed/call-result
  receivers, explicit and implicit current-object receivers, hooks, and
  failed-call rollback all follow the existing expression semantics;
- the ordinary discarded-function warning remains for bare calls and is
  suppressed by an explicit void cast.

The permanent discriminator is
`ivtest/ivltests/sv_object_randomize_statement_with.v`. Current `main`
rejects its legal statement calls during parsing; the fixed build computes
and checks every value and hook count.

Final gates:

- focused clause-18 tests: pass;
- constraints/UVM subset: 22 passed, 0 failed, real DPI;
- `make check`: pass;
- negative suite: 61 passed, 0 failed;
- SVA dual-run: 36 passed, 0 failed;
- vendored ivtest: 3,218 total, exactly 44 expected failures and no
  failure-identity drift;
- bundled VPI: 94 passed, 0 failed;
- dedicated DPI subsystem: 20 passed, 0 failed, 0 skipped, real DPI;
- full UVM: 226 passed, 0 failed, 0 skipped, real DPI;
- installed/relocated `-uvm` frontend: all eight scenarios passed.

Detailed implementation and pre-fix evidence:
`session_logs/2026-07-27_object_randomize_statement_with.md`.

The independent scope-randomization frontier
`std::randomize(vars) with {...}` remains M3B-10 and is not folded into
this object-method campaign.

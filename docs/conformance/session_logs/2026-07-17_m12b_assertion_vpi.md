# 2026-07-17 — M12B: concurrent-assertion VPI object model

Directive: "Continue to M12B" — give concurrent assertions VPI object
identity so `vpi_iterate(vpiAssertion, ...)` enumerates them for
debug/coverage tooling (it returned NULL before).

## The problem

The SVA engine lowers each concurrent assertion in pform to a
synthesized always-block (the token-pipeline checker), so by the time the
design reaches the netlist and vvp there is no "assertion" object left to
enumerate — assertions have no VPI identity. Covergroups (the M12
precedent) survive elaboration as `class_type`s and register at compile
time; assertions do not, so a compile-time registry is not available.

## Approach — runtime registration

Restore identity by having each synthesized checker register itself at
time 0, then serve VPI iteration from that registry.

- **pform.cc** (`sva_register_stmt_`): every synthesized checker's
  zero-init `initial` block now also calls
  `$ivl_register_assertion("assert_L<line>_<inst>", "<file>", <line>)`.
  Applied in both lowering paths (the main linear-chain assertion and the
  temporal `until`/`within`/liveness path).
- **vpi/sys_sva.c**: the `$ivl_register_assertion` systf reads the name/
  file/line args and the call's scope (`vpi_handle(vpiScope, callh)`) and
  forwards to `vpip_register_assertion`. This follows the existing
  `vpip_make_systf_system_defined` cross-module pattern (a `vpip_*`
  extension declared in `vpi_user.h`), so it is portable — the module
  already calls `vpip_*` core functions, no new symbol-export mechanism.
- **vvp/vpi_scope.cc**: `__vpiAssertion` (get_type_code → vpiAssertion;
  vpi_get(vpiLineNo); vpi_get_str(vpiName/vpiFullName/vpiFile);
  vpi_handle(vpiScope)); a global `assertion_registry`;
  `vpip_register_assertion` (create + register + `vpip_attach_to_scope`);
  and `vpip_make_assertion_iterator`.
- **vvp/vpi_priv.cc**: `case vpiAssertion` in `vpi_iterate_global`
  returns the global iterator. Scope-scoped
  `vpi_iterate(vpiAssertion, scope)` needs no new code: `module_iter`
  already returns a subset iterator over the scope's `intern` list
  filtered by `get_type_code()`, and each `__vpiAssertion` is attached
  there.
- **sv_vpi_user.h / vpi_user.h**: `#define vpiAssertion 686` (an unused
  code) and the `vpip_register_assertion` declaration.

## Scope and honesty

Registration is at time 0 (an interpreter approximation of the LRM's
build-time identity) — a tool querying before time 0 sees an empty set,
which is acceptable for runtime debug/coverage use and documented.
Assertion **callbacks** (cbAssertionStart / cbAssertionSuccess /
cbAssertionFailure) and VPI force/release on bit-selects remain for a
follow-up; they need the checker to fire VPI callback events, a further
plumbing step.

The assertion name is synthesized (`assert_L<line>_<inst>`) since the
source label is not threaded to the lowering; file/line/scope are exact.

## Verification

Bundled VPI test `ivtest/vpi/m12b_assert_vpi` (added to
`vpi_regress.list`): three concurrent assertions; the `$check_assertions`
systf verifies `vpi_iterate(vpiAssertion, NULL)` enumerates all three
(each with a non-empty name, a positive line, and a vpiScope handle) and
that the scope-scoped `vpi_iterate(vpiAssertion, top)` returns the same
count. Manual runs confirmed the exact attributes
(`name=assert_L5_0 file=... line=5 scope=top`, …); the committed gold
prints a single deterministic PASS line so the diff is order-independent.

Regression gates: **bundled VPI 80/80** (79 baseline + the new test),
**UVM 177/177** (zero no-check — the per-assertion registration call adds
no output and no regression), **ivtest baseline-identical**, **negative
32/32**.

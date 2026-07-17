# 2026-07-17 — M12B-cb: concurrent-assertion VPI callbacks

Directive: "continue with M12B-cb" — give the assertion VPI objects from
M12B a live callback surface so debug/coverage tooling can be notified
when an assertion succeeds or fails, via
`vpi_register_assertion_cb(assertion, reason, cb, user_data)` with
`cbAssertionSuccess` / `cbAssertionFailure`.

## The problem

M12B gave each synthesized concurrent-assertion checker a VPI identity
(`vpi_iterate(vpiAssertion, ...)`), but the handle was inert: there was no
way to be told *when* an attempt resolved. IEEE 1800-2017 §38.37
specifies `vpi_register_assertion_cb` with the `cbAssertion*` reasons and
an `s_vpi_attempt_info` payload. Nothing in the pipeline emitted a
success/failure event to VPI.

## Approach — checker-emitted report events

Each synthesized checker already runs a fail action and (for pass) reaches
a pass statement. Route both through a VPI report call that fires the
registered callbacks, keyed by `(scope, compile-time idx)` so that a
module instantiated N times keeps N distinct assertion identities.

- **pform.cc**: `sva_report_stmt_(loc, inst, reason)` emits
  `if ($ivl_assert_cb_active()) $ivl_assert_report(inst, reason);`.
  - `sva_fail_action_(loc, inst, action)` wraps every failure-dispatch
    site (all 7) as a block of `[sva_gate_(action),
    sva_report_stmt_(FAILURE)]` — the failure report fires alongside the
    existing `else`/`$error` action and is gated the same way.
  - Success: for `assert`/`assume` (not cover, not a negated property) a
    `sva_report_stmt_(SUCCESS)` is folded into the pass statement.
  - `$ivl_assert_cb_active()` guards both so a design with no assertion
    callbacks registered emits nothing (zero output, zero overhead in the
    common case).
- **vpi/sys_sva.c**: `$ivl_assert_report(idx, reason)` →
  `vpip_assertion_report(idx, reason, vpi_handle(vpiScope, callh))`;
  `$ivl_assert_cb_active()` → `vpip_assertion_cb_active()`.
- **vvp/vpi_scope.cc**: `__vpiAssertion` carries a compile-time `idx_` and
  a `std::vector<assert_cb_t>` of registered callbacks. `fire(reason)`
  builds an `s_vpi_time` from `schedule_simtime()` and invokes each
  callback whose reason matches. A `(scope, idx)` map
  (`assertion_by_key`) resolves a report to the right handle;
  `assertion_cb_total` tracks whether any callback is registered (backing
  `vpip_assertion_cb_active`). `vpi_register_assertion_cb` dynamic_casts
  the handle to `__vpiAssertion`, appends the callback, bumps the total.
- **vvp/vpi_priv.cc**: routine-table population for the four new `vpip_*`
  entries (Windows path).

## Windows portability (the M12B follow-through)

On Linux a module resolves `vpip_*` core symbols directly (`-rdynamic`);
on Windows (`system.vpi` links only `libvpi.a`) every module→core call
MUST go through the `vpip_routines_s` function-pointer table. Adding
callable `vpip_*` functions therefore required, for each of
`vpip_register_assertion` (fixed in M12B commit 78618e3),
`vpip_assertion_report`, `vpip_assertion_cb_active`, and
`vpi_register_assertion_cb`:

1. a field in `vpip_routines_s` (vpi_user.h),
2. a bump of `vpip_routines_version` (now 3),
3. a forwarder in `vpi/libvpi.c` (`assert(vpip_routines); vpip_routines->…`),
4. population in `vvp/vpi_priv.cc`'s Windows routine-table block.

`vpi_register_assertion_cb`'s signature uses `p_vpi_attempt_info`, defined
in sv_vpi_user.h; since vpi_user.h is included widely without it, the
callback typedef forward-declares `struct t_vpi_attempt_info;`.

## Scope and honesty

- Reasons implemented: `cbAssertionSuccess`, `cbAssertionFailure`. The
  `s_vpi_attempt_info` payload is passed as a valid pointer but its
  `detail` union (failing expr / step handles) is not populated — the
  interpreter lowering does not retain the sub-expression object model, so
  step-level introspection would be fabricated. `attemptStartTime` and the
  callback `time` argument are the report time, not a separately tracked
  attempt-start time. Documented rather than faked.
- `cbAssertionStart` / `cbAssertionStepSuccess` / `cbAssertionStepFailure`
  / disable/reset reasons are defined in the header but not yet emitted;
  they need per-attempt lifecycle tracking in the checker (a follow-up,
  M12B-fr territory).
- Success is reported once per pass evaluation of the checker; this is the
  boolean/short-sequence common case. Multi-attempt overlap accounting is
  not modeled.

## Verification

Bundled VPI test `ivtest/vpi/m12bcb_assert_cb` (added to
`vpi_regress.list`): a clocked boolean assertion
`assert property (@(posedge clk) sig)` driven through a known pattern
(1 1 0 1 0). A VPI module registers `cbAssertionSuccess` +
`cbAssertionFailure` on every `vpi_iterate(vpiAssertion)` handle (from an
`initial #1 $setup_assert_cb`, after the time-0 registration inits) and
tallies per-reason counts; `$check_assert_cb(3, 2)` verifies 3 successes
and 2 failures. The committed gold prints one deterministic PASS line.

Regression gates: **bundled VPI 81/81** (80 + the new test), **UVM
177/177** (zero no-check — the report call is gated by
`$ivl_assert_cb_active()` so it is inert without a registered callback),
**ivtest baseline-identical**, **negative 32/32**.

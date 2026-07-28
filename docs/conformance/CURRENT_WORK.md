# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-28

Base: `origin/main` `43d2450`, which already carries PR #123 (VPI
container observability) and PR #124 (`std::randomize(vars) with {...}`
through Z3 at its documented integral-signal boundary).

Three independent closures are landing on top of it. Each was validated
on its own branch against this base; each carries its own permanent
discriminator and its own dated session log.

### PR #125 — covergroup `sample()` from a scope subroutine (M11-8)

A `sample()` call inside a module-, package-, or interface-scope task
compiled without diagnostics but emitted `%covgrp/sample 0, 0`, so
coverage stayed at 0%. Standalone covergroups are synthesized classes and
their coverpoint metadata is built during class elaboration, which ran
*after* the subroutine bodies that referenced it. Class definitions are
now elaborated first in both `PPackage::elaborate` and
`Module::elaborate`; lexical class order — and therefore static
initializer order (I5) — is preserved.

Discriminator: `ivtest/ivltests/sv_covergroup_task_sample.v`, covering
module tasks/functions, package tasks, interface tasks,
`with function sample`, and a chained class-embedded receiver. Pre-fix
the repository reproducer printed `0.0% (want 100)` and the adversarial
matrix reported 0% instead of 50% for every checked form.
Log: `session_logs/2026-07-27_covergroup_scope_subroutine_sample.md`.

### PR #126 — object `randomize() with {...}` in statement position (M3B-16)

The expression form already reached Z3, but the legal bare and
`void'(...)` statement forms were syntax errors, and an older
no-parentheses statement rule accepted the tokens while discarding every
inline constraint. The parser now retains the constraint block on
`PCallTask` and statement elaboration reuses the same randomize-with
builder as expression elaboration. Direct, nested-property, indexed,
call-result, explicit-`this`, implicit-receiver, selector, caller-value,
no-parentheses and void-cast forms all solve through one path; a failed
solve preserves the object, runs `pre_randomize`, and skips
`post_randomize`.

Discriminator: `ivtest/ivltests/sv_object_randomize_statement_with.v`.
Log: `session_logs/2026-07-27_object_randomize_statement_with.md`.

### PR #127 — R15 retired as a stale diagnosis

R15 claimed an unaligned explicit-clock `$past` result was one tick
young. IEEE 1800-2017 16.9.3 selects clocking-event time steps strictly
prior to the time step in which `$past` is evaluated, so a call *on* the
named-clock tick excludes that tick and a call *between* ticks includes
the most recent one. The existing NBA history shift already implements
both. The proposed extra delay would have been a regression, so this
strengthens the permanent test and corrects the roadmap instead of
changing the runtime.

Discriminator: `ivtest/ivltests/sv_sampled_value_explicit_clock.v`, now
covering aligned and unaligned `$past` at depths one and two plus
`$rose`/`$fell`/`$stable`/`$changed` on and between named-clock ticks.
Log: `session_logs/2026-07-27_r15_sampled_history_audit.md`.

### Gates

Each branch ran, against this base, the full hard matrix: `make check`,
the vendored ivtest name-diff (3,217–3,218 total, exactly 44 expected
failures, no failure-identity drift), bundled VPI 94/94, the negative
suite 61/61, the SVA legacy/NFA dual-run 36/36, the dedicated real-DPI
subsystem 20/20 with zero skips, full UVM 226/226 with real DPI and zero
skips, and the installed/relocated `-uvm` front end across all eight
scenarios. CI is green on all six platform jobs for each.

### Next frontier

M9-7 mid-sequence clock flow: the parser still rejects the legal form
`@(c1) a ##1 @(c2) b`. Closure needs a clock-domain boundary in the
sequence representation and a race-free handoff derived from the existing
multiclock implication machinery. Draft PR #128 is an unfinished
checkpoint of that work and is not ready to land.

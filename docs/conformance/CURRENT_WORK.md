# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-27

Branch: `codex/covergroup-task-sample`, based on `origin/main`
`2e5eab5d8` (the merge of PR #123). Draft PR: #125.

The covergroup scope-subroutine sampling closure is complete:

- current `main` compiled a `sample()` call inside a module-scope task
  without diagnostics but emitted `%covgrp/sample 0, 0`, so coverage
  remained 0%;
- package, module, and interface class/covergroup metadata is now
  elaborated before ordinary scope function/task bodies;
- lexical class order, static initializer order, generated scopes,
  runtime variable initialization, and behavior ordering are preserved;
- the permanent regression covers module tasks/functions, package tasks,
  interface tasks, `with function sample`, and a chained class-embedded
  covergroup receiver.

Discriminating pre-fix evidence:

- the repository reproducer printed `0.0% (want 100)`;
- the five-form adversarial matrix reported 0% instead of 50% for every
  checked receiver/subroutine family;
- after the fix the reproducer reports 100% and the permanent matrix
  passes all value checks.

Final gates:

- focused covergroup family: 7 passed, 0 failed;
- `make check`: pass;
- negative suite: 61 passed, 0 failed;
- SVA dual-run: 36 passed, 0 failed;
- vendored ivtest: 3,218 total, exactly 44 expected failures and no
  failure-identity drift;
- bundled VPI: 94 passed, 0 failed;
- dedicated DPI subsystem with real DPI: 20 passed, 0 failed, 0 skipped;
- full UVM with real DPI: 226 passed, 0 failed, 0 skipped;
- installed/relocated `-uvm` front end: all eight scenarios passed.

Detailed implementation and pre-fix evidence:
`session_logs/2026-07-27_covergroup_scope_subroutine_sample.md`.

M11 remains honestly bounded by its documented loud residuals; this
campaign changes no public FULL/substantial claim.

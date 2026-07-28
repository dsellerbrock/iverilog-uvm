# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-27

Branch: `codex/unaligned-sampled-history`, based on current `origin/main`
after PR #123 (`2e5eab5d8`).

R15 is closed as a stale diagnosis, not an implementation change.
IEEE 1800-2017 16.9.3 selects clocking-event time steps strictly prior to
the time step in which `$past` is evaluated. Therefore:

- a call on the named-clock tick excludes that tick;
- a call between named-clock ticks includes the most recent tick.

The existing NBA history shift already implements both cases. The
permanent explicit-clock regression now checks aligned and unaligned
`$past` at depths one and two, plus `$rose`, `$fell`, `$stable`, and
`$changed` on and between named-clock ticks. It would fail the proposed
extra-delay “fix.”

Validation completed:

- focused ivtest: pass;
- `make check`: pass;
- SVA legacy/NFA dual-run: 36/36;
- vendored ivtest: 3,217 total, exactly 44 expected failures and no
  failure-identity drift;
- bundled VPI: 94/94;
- negative diagnostics: 61/61;
- installed/relocated `-uvm` front-end: all eight scenarios pass;
- full UVM with real DPI: 226/226, zero skips;
- dedicated real-DPI subsystem: 20/20, zero skips.

Detailed evidence:
`session_logs/2026-07-27_r15_sampled_history_audit.md`.

The next confirmed implementation frontier is M9-7 mid-sequence clock
flow. Its parser currently rejects the legal form
`@(c1) a ##1 @(c2) b`; closure needs a clock-domain boundary in the
sequence representation and a race-free handoff derived from the existing
multiclock implication machinery.

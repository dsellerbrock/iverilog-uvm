# CURRENT WORK — continuation state

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-27

Branch: `codex/std-randomize-with-z3`, rebased onto current `main`
(`2e5eab5d8`, including merged VPI container-observability PR #123).
Draft PR: #124.

M3B-10 is implemented at the integral-signal boundary:

- `std::randomize(a, b) with {...}` reaches Z3 in statement,
  `void'(...)`, and expression contexts;
- supported destinations are simple integral scalar/packed-vector signals
  from 1 through 64 bits, including enums and automatic locals;
- call-time state references, cross-variable constraints, `inside`, soft,
  conditional, and UNSAT behavior are covered;
- a successful solve writes every model value through the ordinary signal
  store; failure returns zero and preserves every destination;
- selected/container destinations, arrays, and variables wider than 64 bits
  remain loud unsupported forms.

Discriminating pre-fix coverage reported six failures: statement and
expression constraints were violated, signed/unsigned widths were wrong,
UNSAT returned success, and failed solves changed destinations. The permanent
regression now passes. A full ivtest name diff also caught and fixed one
mixed-sign regression in the shared class solver before checkpointing.

Final integrated gates:

- focused scope and adjacent class-constraint regressions: pass;
- `make check`: pass;
- constraint UVM group: 22 passed, 0 failed, 0 skipped;
- real-DPI group: 20 passed, 0 failed, 0 skipped;
- SVA dual-run: 36 passed, 0 failed;
- vendored ivtest: 3,218 total, exactly 44 expected failures, no identity
  drift;
- bundled VPI: 94 passed, 0 failed;
- negative suite: 61 passed, 0 failed;
- full UVM with real DPI: 226 passed, 0 failed, 0 skipped;
- installed/relocated `-uvm` front end: all eight scenarios passed.

The campaign is complete at its documented integral-signal boundary. Resume
from the next confirmed severity-ordered frontier after PR #124 merges; do not
expand this PR into arrays, selected/container destinations, or wider-vector
randomization without a new bounded campaign.

Detailed evidence:
`session_logs/2026-07-26_std_randomize_scope_z3.md`.

# Caliptra formal-verification-source grounding — L120 found and fixed (2026-09-16)

## Context

Objective 4 ("a standards-correct frontend suitable for eventual formal
verification") and objective 5 ("make unmodified ... Caliptra fully
usable for ... formal-oriented elaboration") had not been directly
exercised this session. Rather than continue synthetic-reducer probing,
tried compiling real, unmodified files from Caliptra's actual formal
verification tree (`submodules/adams-bridge/formal/`, 141 `.sv` files,
authored by LUBIS EDA for real commercial formal tools) directly against
the Icarus frontend.

## What compiled clean

- `fv_cbd_sampler_constraints.sv` + its package dependency: clean,
  first try. 2D packed array ports, `$stable`, `default clocking`,
  constructor-independent value bins.
- A full multi-file `bind`-based checker injection setup
  (`fv_ntt_butterfly_*` + the real `ntt_butterfly` RTL and its full
  sub-instance hierarchy — `abr_ntt_add_sub_mod`, `barrett_reduction`,
  `ntt_mult_dsp`, `ntt_mult_reduction`, `ntt_div2`, `abr_adder`, resolved
  via `-y` library directories): clean compile, real 279KB `.vvp`
  generated. This is a substantial, real, unmodified formal testbench —
  package imports across files, `bind` with expression-valued (not just
  plain-signal) port connections against the bound module's own
  hierarchy, deep real RTL instantiation.

## What didn't — L120

`fv_ntt_ctrl_constraints.sv` (real, unmodified) hit a genuine defect: a
completely action-less `assume property (s_eventually(pi_ntt_enable));`
(no `else`, no pass action — literally nothing after the closing paren
but `;`) was wrongly rejected with `sorry: a pass action on this
property operator is not supported`. Full root-cause, fix, and
validation in `docs/conformance/BLOCKERS.md`'s new **L120** entry. Fixed
with a one-line change (an overly narrow `kind == 2` guard on an
existing sentinel-clearing check).

Re-tested the exact originally-failing file after the fix: the two
`sorry:` errors are gone. (Unrelated warnings remain on that file when
compiled standalone outside its full `bind` context — expected, not a
regression.)

## Also verified correct (real Caliptra RTL, not formal)

- `default clocking` used purely to infer a clock for `$changed()` and
  for an assertion with no explicit clocking event (real pattern, 105
  files in Caliptra use `default clocking`): both inference paths
  confirmed correct via manual trace.
- `priority case (1'b1)` (real pattern, 3 uses in `kmac.sv`/
  `kmac_app.sv`/`kmac_errchk.sv`): runtime "unhandled" violation report
  fires exactly when no branch matches, priority-order resolution
  correctly favors the first listed match with no spurious warning when
  multiple branches would match.

## Takeaway

Grounding construct verification in a real, unmodified, actively
maintained silicon project's actual source — rather than only
hand-written reducers — surfaced a real defect (L120) that no amount of
synthetic `s_eventually` testing in isolation would likely have found,
because the trigger (a *completely action-less* liveness assert/assume)
is an unusual enough shape that no existing `ivtest` reducer exercised
it, yet it's a perfectly ordinary thing to write and is exactly what a
real commercial-EDA-authored formal testbench does.

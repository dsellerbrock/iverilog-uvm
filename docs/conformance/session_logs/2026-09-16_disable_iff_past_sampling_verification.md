# `disable iff` + `$past()` sampling interaction — verified correct (2026-09-16)

## Scope

A speculative reducer (compound: `disable iff` + `$past()` + a
multi-tick reset sequence, all in one shot) produced an unexpected
`FAILS=1` result. Rather than write that up as a defect, this was
investigated properly per IEEE 1800-2017/2023 §16.12 (`disable iff`) and
§16.9.3 (`$past`), because a compound reducer's own oracle is easy to get
wrong by hand — which is exactly what happened.

## Finding: no defect. The original reducer's oracle was wrong.

Two foundational mechanisms were verified independently, each with a
manual-trace reducer whose expected values were derived directly from
LRM text (not assumed):

1. **`$past()` basic sampling** — three ticks, `a` changed between each:
   traced output `$past(a) = 0, 1, 2` at ticks 1/2/3, matching §16.9.3
   ("the sampled value of expression1 in a particular time step strictly
   prior to the one in which `$past` is evaluated") and the default
   sampled value (0, for `a`'s zero-initialized state) before any prior
   tick exists.
2. **`disable iff` pass/fail suppression** — a trivially-false property
   body, disabled only during one of three ticks: failure fired at
   ticks 1 and 3, correctly suppressed (no failure) at the disabled
   tick 2, matching §16.12 ("A disabled evaluation of a property does
   not result in success or failure").

Combined: `$past()`'s sampling is **unconditional** — it is not part of
property pass/fail evaluation, so a `disable iff` condition does not
suspend it. A signal changed during a disabled tick is still correctly
visible to `$past()` one tick later. Verified directly: `$past(a)` at a
tick sampled *while disabled* correctly returned the value from the
*previous* (non-disabled) tick, and a *later* (non-disabled) tick's
`$past(a)` correctly returned the value the signal held *during* the
disabled tick — proving sampling continuity straight through a disabled
attempt, not staleness or a skip.

The original compound reducer's "FAILS=1" was Icarus behaving correctly;
the reducer's own oracle incorrectly assumed `disable iff` would also
hide history from `$past()`, which no LRM text supports and this
investigation now directly contradicts.

## Self-caught authoring bug (worth recording, not an Icarus defect)

The first attempt to turn this verified-correct behavior into a
permanent `ivtest` regression **hung** (`vvp` ran at 99% CPU
indefinitely). Traced to the test itself, not Icarus: the file used a
free-running `always #5 clk = ~clk;` clock generator but only called
`$finish` inside early-exit failure guards — the success path fell
through to `$display("PASSED");` with no `$finish`, so the clock
generator ran forever with nothing left to terminate the simulation.
Any simulator would hang on this. Fixed by adding an unconditional
`$finish` after the success message; confirmed the corrected test now
terminates immediately and passes.

## Permanent regression added

`ivtest/ivltests/sv_disable_iff_past_sampling_unconditional.v` (normal),
registered in `ivtest/regress-sv.list`. This is defensive coverage for a
confirmed-correct, non-obvious interaction — not a defect fix — added
because no existing test combined `disable iff` and `$past()`, and a
future scheduling change to either mechanism could regress this silently
otherwise (this exact pairing is realistic: an OpenTitan-style
report-catcher/scoreboard checker commonly has a `disable iff`'d
assertion whose body also references `$past` on the same signal).

## Validation

Full `.github/ivtest_gate.sh` legacy sweep re-run with the new test
included; see the PR for the exact counts.

# R15 sampled-history audit — 2026-07-27

## Outcome

R15 was retired without a runtime change because its expected result was
backwards.

IEEE 1800-2017 16.9.3 defines `$past` using clocking-event time steps
strictly prior to the time step where the call is evaluated. Consequently:

- on a clocking-event tick, `$past(x, 1, ..., @ev)` returns the sample from
  the preceding `ev` tick;
- between `ev` ticks, the most recent `ev` tick is strictly prior and is
  the depth-one result.

The same time-step rule applies to `$rose`, `$fell`, `$stable`, and
`$changed`: the expression's value in the call's current time step is
compared with its sample from the most recent strictly-prior clocking-event
time step. A signal that changes between named-clock ticks can therefore
report the change before the next named-clock tick; once that tick samples
the new value, an unaligned later call reports stable.

The existing sampler's NBA history shift already produces these results.
Aligned Active-region readers run before the shift; later unaligned readers
see it completed. Moving the shift earlier or adding another history slot
for unaligned reads would introduce the wrong extra delay.

## Evidence

`ivtest/ivltests/sv_sampled_value_explicit_clock.v` now checks:

- aligned and unaligned readers of the same explicit named clock;
- depths one and two;
- rising, falling, stable, and changed comparisons both on and between
  named-clock ticks;
- stable results when no named-clock tick intervenes;
- explicit-clock precedence over both an enclosing event and default
  clocking.

The extended test passes on current `main`. Its unaligned expected sequence
is the opposite of the proposed R15 change, so it discriminates the
misdiagnosis from the required behavior.

Final gates are clean: focused ivtest, `make check`, 36/36 SVA dual-run,
3,217-test ivtest name-diff with exactly 44 expected failures, 94/94 VPI,
61/61 negative diagnostics, 226/226 full real-DPI UVM with no skips, 20/20
dedicated DPI with no skips, and all eight installed/relocated `-uvm`
front-end scenarios.

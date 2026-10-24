# IEEE 1800 §16.9.3 sampled-value probes

This run uses the existing procedural, default-clocking, explicit-clock,
Preponed-writer, multiclock-assertion, and `$sampled` regressions, plus a
negative call with no available clock. It runs each under `-g2017` and
`-g2023`, with assertions enabled. The existing clocking-input rejection case
is included as a separate diagnostic probe. Each compiler and simulation
invocation has a 120-second timeout. The first runner attempt (job 3180) failed
before compilation due to shell variable initialization under `set -u`; it is
recorded separately as a harness failure.

Slurm job 3181 ran only the `.sv` inputs because the copy glob omitted the
existing regression files with `.v` suffix. It validly confirms that the
`$sampled` assertion probe passes in both editions and exposes the missing
clock behavior in both: compile succeeds with a warning, then `$past(sampled)`
returns the current `1` value. The full run in attempt 12 includes both source
suffixes and repeats these probes.

# IEEE 1800 §16.9.3 sampled-value probes — extension-aware rerun

Runs existing sampled-value regressions in both `-g2017` and `-g2023` modes,
with assertions enabled. Coverage includes procedural `$past`/value-change
functions, default-clock inference, explicit clock arguments, Preponed
sampling, multiclock assertions, `$sampled`, the unsupported clocking-input
form, and a no-clock diagnostic probe. Each compile and simulation has a
120-second timeout. Attempts 10–12 preserve runner/setup failures and valid
no-clock observations; this attempt stages both the regression `.v` files and
standalone `.sv` probes and chooses the staged source suffix explicitly.

## Slurm job 3183 results

Compiler source was `6604c23e197980b69a5b6b69864ff8ef8d05eba3`, Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`, and
VVP SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.
All six positive existing tests passed in both editions: procedural history and
value-change functions, default-clock inference, explicit clock arguments,
Preponed writer ordering, multiclock assertions, and `$sampled` in a property.

Two standard-supported cases expose gaps in both editions. The clocking-block
input `cb.d` case is rejected at compile time as unable to lower its required
IEEE 1800 §16.5.1 sampling/lifetime rules. A `$past` call with no assertion,
procedural, explicit, or default clock compiles with a warning and returns the
current value instead of diagnosing the invalid use under §16.9.3. The
separate blocking-update probe in attempt 14 confirms `$sampled` outside a
property also reads the live value after an Active-region write rather than
retaining the current time-step sample required by §16.9.3.

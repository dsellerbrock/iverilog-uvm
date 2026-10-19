# Issue #679 — default-clock sampled-value calls in event controls

## Implementation

Feature commit: `533556356` (`fix: handle default-clock sampled-value event controls`).
Final branch head after merging current `origin/main`: `b965f0d2abcc98d66f4d463386318164c5a3a045`.

IEEE 1800-2017 and 1800-2023 §16.9.3 permit sampled-value functions in procedural code and infer default clocking outside assertions. Before the first clock, the four value-change functions compare against the argument's default sampled value (§16.5.1). A Boolean result therefore starts at 0 for `$changed`, `$rose`, and `$fell`, and 1 for `$stable`. Procedural event controls react to either value transition (§9.4.2).

The event waiter now starts with that constant result, polls only at the inferred default clock, stores the new result before running the event body, and diagnoses other functions such as wide `$past` rather than coercing them into a one-bit value.

## Verification on the merged branch head

Host: macOS 27.0, arm64. Build: `make -j3 && make install`, 5.91 s, peak RSS 147,390,464 bytes. Initial configured build of this feature also passed in 40.40 s, peak RSS 1,359,413,248 bytes. Optional Homebrew headers were exposed with `CPATH=/opt/homebrew/opt/libffi/include:/opt/homebrew/opt/z3/include`; library paths with `LIBRARY_PATH=/opt/homebrew/opt/libffi/lib:/opt/homebrew/opt/z3/lib`.

- Exact issue reproducer compiled and ran under `-g2017` and `-g2023`; both printed `changed at 5`, compile and run exit 0. Raw source and logs are in `attempt-09-main-merged/`.
- `sv_sampled_value_default_clocking.v` passed in both editions. Its checks cover `$changed` transitions at t=5, 15, 25, and 45; suppression at t=35; `$stable` initial value; sampled-region race transitions at t=45 and 55; and ordinary procedural `$past`/`$rose` behavior.
- `@($past(data))` in a default-clock event control produced the direct unsupported-feature diagnostic and the expected compile failure in both editions.
- Focused legacy T1: 7/7 passed. Focused JSON/VVP T1: 12/12 passed.
- `ci/run-smoke.sh`: 133/133 smoke tests and 56/56 VPI tests passed; `run-repros.sh` reports #544 as the expected §7.6 compile error. Total 181.81 s, peak RSS 114,163,712 bytes.

Tool hashes:

- `iverilog`: `e2dc374cbd00c5fa59cd537e5329a28e064b42f3a0c70f154f655f1be8f836d3`
- `vvp`: `bb821914cbcf1124505af3743df802faaff3625128d64a4ff2fc39b5001a0f76`

The full smoke output, focused runner outputs, per-edition reproducer logs, paired-regression logs, and `$past` diagnostics are retained in `attempt-09-main-merged/`.

## Summary

<!-- What does this PR change, in a sentence or two? -->

## Motivation / bug

<!-- What failure or missing feature does this address? Paste the minimal
     reproducer (or link the reduced test) and the wrong behavior it showed. -->

## IEEE 1800 reference

<!-- Relevant clause/subclause (e.g. "18.5.4 dist"), or N/A for changes that
     are not language-semantic (build, CI, docs, refactoring). -->

## Root cause

<!-- What was actually wrong (parser rule, elaboration, codegen, runtime,
     scheduling, ...)? Not just the symptom. -->

## Implementation

<!-- Brief description of the approach. Note anything deliberately scoped out. -->

## Tests added

<!-- New regression tests: tests/*.sv, tests/negative/*.sv, ivtest entries.
     Bug fixes should include the reduced reproducer as a permanent test. -->

## Validation

<!-- Check what you ran; delete lines that genuinely don't apply. -->

- [ ] Focused tests for this change pass
- [ ] Negative tests pass where applicable (`tests/negative/run_negative.sh`)
- [ ] UVM regression passes where applicable (`./.github/uvm_test.sh`)
- [ ] ivtest regression checked where applicable (`cd ivtest && perl vvp_reg.pl`) — no new failures vs. the recorded baseline
- [ ] VPI regression checked where applicable (`cd ivtest && perl vpi_reg.pl`)
- [ ] No new silent fallback introduced (unsupported paths are a loud error/sorry/warning)
- [ ] Remaining unsupported behavior is documented (clause matrix / recorded corners)

## Compatibility

<!-- Mark any area this change affects and say how. -->

- [ ] Upstream-compatible Verilog (IEEE 1364) behavior
- [ ] VVP runtime / bytecode
- [ ] VPI ABI/API
- [ ] DPI ABI/API
- [ ] Scheduler / event-region ordering
- [ ] Parser grammar (`parse.y` — note any new conflicts)

## Known limitations

<!-- What does this PR intentionally NOT implement? Partial support is fine —
     undocumented partial support is not. -->

## Documentation

<!-- Docs/conformance records updated (clause matrix, CURRENT_WORK, session
     log), or "none needed". -->

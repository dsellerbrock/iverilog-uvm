# Whole local fixed-array patterns — L106

IEEE 1800-2017 and 1800-2023 10.9,13.4.3. FOCUSED_TESTED;
required broad batch qualification remains pending.

Whole-array assignments in constant functions reached the element-store path
without an element selector and crashed. The evaluator now reuses recursive
assignment-pattern flattening, checks the exact number of leaves, converts
all values before replacing local slots, and preserves selected-element stores.

Paired regressions compare constant and runtime string/integral arrays,
nonzero and reversed bounds, signed conversions, whole-array reassignment,
nested/default patterns, automatic recursive frames, const initialization,
readonly rejection and malformed shapes. The focused legacy and JSON paths
each pass 10 tests; neighboring methods, character updates and nonlocal-state
checks each pass 42. No expected semantic output was weakened.

The [validation record](2026-09-15_constant_local_array_patterns_validation.json)
records the composite installed candidate, raw results and hashes. Pending
L107/L108 changes were present during these scoped checks, and the OpenTitan
L108 reducer remains failing; this is not qualification of those changes.

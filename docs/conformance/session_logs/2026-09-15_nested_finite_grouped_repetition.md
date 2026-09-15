# Nested finite grouped repetition

IEEE1800-2017 and2023 16.9.2 repeat the complete sequence operand. The prior flat group flags rejected nested multi-term Boolean/delay groups.

Each retained group now has an ID, ordered opening/closing metadata and per-step membership. Expansion removes only the current group and recursively retains inner copies. Inner empty/nonempty branches use the existing suffix composition rules; an empty-language nonzero body no longer discards a valid outer zero-copy alternative. Fixed multiclock prefixes/consequents recursively materialize positive exact nested counts, preserving complete operands and action times.

[Focused evidence](2026-09-15_nested_finite_grouped_repetition_validation.json) records paired exact/ranged/zero cases, exact parent verdicts and times, fixed prefix/consequent checks, a 64-tick witness with an early false destination, Kill/restart, same-clock runtime behavior and illegal/unsupported boundaries. The formerly unsupported nested negative now requires one runtime parent failure at195. Earlier failed candidates and diagnostic corrections remain in raw evidence.

Admission of newly supported nested shapes is bounded to1024 expanded physical steps, computed by summing each step's containing-group count product. Disjoint groups add, and zero outer repetition creates no expansion. This is a compiler construction limit, not an IEEE restriction or a bound on outstanding assertion obligations. Existing multiclock depth64 remains. Nested ranged fixed consequents, unbounded groups and broader sequence operands remain incomplete. Broad batch qualification is pending.

# L94 — Finite grouped multiclock repetition

IEEE 1800-2017/2023 16.9.2 repeats the whole sequence fragment. The parser previously expanded a group in a representation that could only vary its last Boolean; multiclock admission rejected the form. The new carrier preserves group boundaries, counts and intrinsic leading delays. The automaton repeats every term and retains each permitted endpoint under the existing parent-attempt lifecycle.

Zero-copy branches follow 16.9.2.1 separately from nonempty branches. A recursive suffix builder preserves their different delay composition, drops forbidden zero-delay empty paths and distinguishes an empty language from an empty match. Nondegeneracy restrictions in 16.12.22 still reject a pure no-match antecedent or an only-empty overlapping antecedent. Adjacent groups retain the actual prefix context during suffix construction.

Review found a shared-parser regression in fixed multiclock prefixes/consequents: retained groups could become a single copy. The fixed path now materializes complete exact copies, preserves intrinsic versus external delay, and restricts the earliest-match relaxation to trailing ranged consequent groups. A grouped antecedent cannot fall through to the fixed path when its NFA is rejected, including at the 64-tick boundary.

[Exact focused evidence](2026-09-15_multiclock_grouped_repetition_validation.json) records paired positive, negative and boundary cases, runtime parent verdicts, empty composition, prefix/consequent compatibility and neighboring suites. Both private lists contain 58 tests. The prior L91 grouped compile-error case now checks a real parent failure after its second child; it was retained, not removed.

The flat-group subset is implemented with focused evidence. Nested groups, unbounded forms, internal ranged multiclock consequents and broader SVA remain separate. Broad compiler/UVM qualification is pending; this supplies simulation/elaboration semantics, not a hardware proof backend.

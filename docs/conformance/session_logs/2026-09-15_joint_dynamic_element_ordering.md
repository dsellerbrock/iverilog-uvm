# L88 — Joint dynamic-array selected-element ordering

Constant selected integral dynamic-array elements now retain their ordering
operands through elaboration and use the existing canonical element stages in
joint randomization. The size vector must have exactly one proved value before
ordered element sampling. Bounds are checked against that size, so allocation
growth and shrinkage do not use the old container size as a constraint.

Applicable clauses are IEEE 1800-2017 18.4, 18.5.8.2, 18.5.9/18.5.10 and
IEEE 1800-2023 18.4, 18.5.7.2, 18.5.8/18.5.9. The existing staged distribution,
size limits and graph transaction machinery are reused. Queues, associative
arrays, nonconstant selectors and active randc ordering remain separate.

Boundary review found that a 64-bit index could narrow to an unsigned element
identity and silently select element zero. The shared dynamic-element IR parser
now reports the original index before narrowing. Existing error propagation
rejects it; no replacement element identity is fabricated.

Ten cases per harness pass on the final candidate. Eight passed the initial
full focused run; the two negative cases were rerun after correcting only
expected diagnostic spelling and the 32-bit interpretation of signed -1.
The tests retain probability/fiber checks, signed and enum relations, aliasing,
resize, frozen modes, distributions, size-zero replay, and value/RNG/callback
rollback for invalid bounds, ambiguous size and enumeration limits. Fourteen
dynamic neighbors pass on this candidate; 41 ordering/transaction neighbors
passed before the final narrow index guard. See the
[validation record](2026-09-15_joint_dynamic_element_ordering_validation.json)
for commands, hashes and preserved failures.

The compiler also contained an independently unfinished L86 SVA increment.
These focused solver results do not qualify that work. Broad batch gates remain
pending at approximately ten integrated fixes; no new whole-application replay
or full-clause conformance is claimed.

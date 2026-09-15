# Finite Boolean repetition in multiclock antecedents — 2026-09-15

L91 extends the L86 parent-attempt engine to finite literal Boolean consecutive
repetition, including legal empty alternatives. Every endpoint creates a child
obligation; each original attempt produces one verdict after its required
children and source lifetime resolve. Both editions are checked separately.

IEEE 1800-2017 and 2023 clauses 16.9.2/16.9.2.1 govern repetition and empty
composition; 16.12.7 governs implication handoff, 16.12.22 nondegeneracy,
and 16.13/16.14 clock flow and actions. An empty nonoverlapped antecedent
uses the nearest consequent clock tick from its start. An exact empty
antecedent is rejected for overlapped implication.

The existing NFA represents finite repetition and records epsilon-only
acceptance. Parser provenance distinguishes grouped repetition from a Boolean
operand without changing existing same-clock group expansion. The multiclock
engine keeps empty records separate from ordinary endpoint consumption so a
coincident clock cannot consume a regular nonoverlapped endpoint too early.
Its cancellation scan restarts at the new epoch origin to retain fresh empty
obligations emitted before the destination clock resumes. Existing consequent
minimum-copy handling remains intact.

[Focused validation](2026-09-15_multiclock_boolean_repetition_validation.json)
records the commands, source/artifact hashes, paired cases and neighbors.
The first candidate asserted on a guardless exact-empty NFA; that invariant
was corrected. Kill/restart originally lost fresh obligations and is repaired.
The range fixture initially enabled a second parent, and a restart fixture
expected time 95 although every child correctly resolves at 75; their expected
behavior was corrected from the clock schedule, preserving failed evidence.

The finite NFA bound remains 64 ticks. Grouped ranged and unbounded repetition,
goto/nonconsecutive repetition, general match actions and broader SVA remain
separate. DD032 records the independently reproduced fixed-path assertion
control defect. Broad batch gates and application qualification remain pending;
these focused results do not qualify the unrelated active enum-update patch.

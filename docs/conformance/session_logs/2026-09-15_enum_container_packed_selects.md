# Enum container packed selects — 2026-09-15

L90 admits packed selects on enum elements of class dynamic arrays and queues.
The frontend retains the exact enum dimensions and two-/four-state base while
forming the selected vector type; it preserves whole-enum nominal assignment
rules. IEEE 1800-2017/2023 clauses 6.19/6.19.3 and 11.5.1 govern those distinctions.

Increment/decrement follows clause 11.4.2: capture the receiver, word selector
and packed selector once, return the proper old/new selected value, and update
only the addressed bits. The target reuses object and vector stacks; a narrow
object-container partial-store instruction clips into the existing word using
the existing resize helper and notifies the existing mutation mechanism. The
instruction consumes the replacement, leaving the yielded expression value.
The common packed-select target applies two-state conversion after selection,
so invalid two-state bit reads yield zero rather than a newly generated X.

[Focused validation](2026-09-15_enum_container_packed_selects_validation.json)
records paired runtime/negative cases, neighboring packed-update checks,
source/artifact fingerprints, and extra clipping/nominal-type controls.
Receiver rebinding and neighboring-bit changes in selector functions verify
capture and read-modify-write behavior across repeated updates.

Preserved failures include unsupported target lowering, incorrect two-state
result conversion, an inaccessible type-mutator attempt, and extra object-stack
cleanup after a consuming load. Test corrections include packed bit arithmetic,
an invalid two-state prefix increment returning one from a zero read while
suppressing the store, and exact diagnostic paths. The full-width selected
vector write remains legal while the uncast whole-enum assignment rejects.

This does not implement method-call-result property chaining syntax or extend
the runtime container index range. Broad batch gates and application replay
remain pending; the focused result is limited to the recorded receiver forms.

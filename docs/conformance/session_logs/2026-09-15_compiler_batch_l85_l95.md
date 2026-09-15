# L85–L95 local compiler qualification

All seven required gates passed for candidate `d45ee87abc65fbfd10c4897f9726bfe53d7d8055`, with semantic source `e43ecd536`. Source and installed artifact fingerprints remained unchanged. The [qualification JSON](2026-09-15_compiler_batch_l85_l95_qualification.json) owns counts, fingerprints and gate evidence.

Eleven bounded fixes were integrated:

- L85: [Joint ordered distributions and RNG rollback](2026-09-14_joint_ordered_distribution.md), `9f416e09a`.
- L87: [Fixed selected-element ordering](2026-09-14_joint_element_ordering.md), `831cdeca2`.
- L88: [Dynamic selected-element ordering](2026-09-15_joint_dynamic_element_ordering.md), `d6a15ca2b`.
- L89: [Queue selected-element ordering](2026-09-15_joint_queue_element_ordering.md), `1ffe476b6`.
- L86: [Bounded multiclock antecedents](2026-09-15_multiclock_bounded_antecedents.md), `13fee7ec9`.
- L91: [Finite Boolean multiclock repetition](2026-09-15_multiclock_boolean_repetition.md), `fec7a4b9a`.
- L90: [Enum container packed selects](2026-09-15_enum_container_packed_selects.md), `6cf8d70de`.
- L92: [Fixed multiclock Off/Kill control](2026-09-15_fixed_multiclock_assertion_control.md), `9f34faa98`.
- L93: [Constant numeric string formatting](2026-09-15_constant_string_formatting.md), `701e116bd`.
- L95: [Constant string putc](2026-09-15_constant_string_putc.md), `5366be16a`.
- L94: [Finite grouped multiclock repetition](2026-09-15_multiclock_grouped_repetition.md), `1db987101`.

The [regression repair record](2026-09-15_batch_l85_l95_regression_repair.md) preserves the failed first candidate and the packed-select, supported-negative and randc-oracle corrections. These corrections are part of the eleven fixes.

The UVM suite used its existing `-g2012` invocation with real DPI; this is not separate full-UVM qualification in 2017 and 2023 modes. Edition-specific focused regressions remain recorded per fix. Full IEEE, UVM, OpenTitan/Caliptra and formal goals remain incomplete. Nested finite groups and illegal non-input constant-function formals are reproduced next candidates, not implemented by this batch.

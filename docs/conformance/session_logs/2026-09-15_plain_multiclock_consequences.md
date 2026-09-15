# L102 — Plain multiclock finite consequences

IEEE 1800-2017 and 1800-2023 16.9.2, 16.13.1 and 16.13.2 permit fixed first-clock sequence prefixes followed by finite second-clock alternatives. A plain sequence used as a property succeeds if a match exists from its starting point. Previously this consequence shape received a focused unsupported diagnostic.

The existing finite source NFA now supplies START/MATCH/CLOSE records from the fixed prefix, feeding L100's unchanged consequence masks. The obsolete borrowed prefix-slot view is cleared. A plain attempt whose prefix never matches fails when that prefix is exhausted; it does not inherit implication vacuous success. Implication behavior and the existing fixed plain path are preserved.

The [validation record](2026-09-15_plain_multiclock_consequences_validation.json) includes paired early/late/all-dead outcomes, first-guard and later-prefix failure, multi-tick prefixes, ##0/##1 clock boundaries, reversed coincident clock order, overlapping starts, one cover verdict, Off/Kill/asynchronous disable/restart, paused destination backlog and finite/unbounded boundaries. An initial overlapping-start stimulus only supplied the second attempt's endpoint; the corrected stimulus supplies both distinct late endpoints and requires two passes.

Focused and neighboring suites pass on the newly rebuilt Command Line Tools candidate; broad qualification is pending. Finite ranged first-clock prefixes remain unsupported, because their alternative prefix matches require a distinct existential result rule. The existing finite construction bound is not an IEEE restriction.

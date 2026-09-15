# Finite first_match multiclock prefixes — L107

IEEE 1800-2017 and 1800-2023 16.9.8,16.13.1,16.13.2.
FOCUSED_TESTED; required broad batch qualification remains pending.

The finite multiclock source NFA now admits a direct Boolean first_match
chain with at most one finite delay window. Its earliest matching source tick
publishes the endpoint and closes that source attempt, so a later endpoint
cannot rescue an earlier destination failure. The destination machinery and
ordinary plain/implication aggregation remain shared with existing paths.

Paired regressions cover earliest failure/success, absent endpoints, exact
windows, implication, reversed event order, overlapping attempts, cover once,
Off/Kill/disable/restart controls and destination backlog. Construction depth64
is exercised by [1:63], while [1:64] exceeds the existing 64-tick limit.
Unsupported unbounded, nested, match-item and multiple-window forms retain
focused compile failures. These boundaries are implementation limits, not
IEEE language restrictions; broader first_match support remains unfinished.

The [validation record](2026-09-15_first_match_multiclock_prefix_validation.json)
records 36 focused cases and 90 neighbors passing in both harnesses, plus
58 NFA dual-run checks. Installed candidate provenance is explicit; the
independent unfinished OpenTitan lookup change is not qualified by these tests.

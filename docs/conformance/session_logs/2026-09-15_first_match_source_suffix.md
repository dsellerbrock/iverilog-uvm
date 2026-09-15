# first_match prefix with a source-clock suffix — 2026-09-15

FOCUSED_TESTED; broad qualification pending.

A direct finite Boolean first_match prefix may now be followed by a fixed
finite Boolean/delay suffix on the same clock before the existing multiclock
handoff. NFA edge provenance preserves the wrapper boundary. The earliest
wrapper exit discards still-inside paths while all tied exits continue through
the suffix; source completion publishes existing MATCH/CLOSE records.

Zero-delay fusion retains wrapper-only guards separately from the full
transition guards. This matters when the earliest wrapper match has a false
same-tick suffix: the attempt must fail rather than retry a later wrapper
match whose suffix would succeed. The initial candidate violated this rule;
the retained discriminator caught it. Correct failure occurs at tick30, when
no continuation remains, rather than the initially assumed maximum tick50.

Both harnesses pass72 cases:20 new paired outcomes plus52 migrated/neighbor
cases. The shared NFA compatibility gate passes58. Coverage includes plain
and implication/cover aggregation, tied exits, zero-delay no-rescue, coincident
handoffs, cancellation/restart, destination backlog, depth64 and depth65/ranged
suffix diagnostics. The former L107 nested-prefix negative now has a checked
runtime oracle. Other unsupported shapes remain explicit.

[Revision-scoped evidence](2026-09-15_first_match_source_suffix_validation.json)
retains failed candidates, corrected test expectations, exact commands and
source/tool fingerprints. No whole-clause, broad-batch or application
qualification is inferred from these focused results.

# Finite multi-window first_match source prefixes — 2026-09-15

FOCUSED_TESTED; broad qualification pending.

Direct finite Boolean first-clock chains can contain multiple literal delay
windows inside first_match. Existing NFA construction and depth checks bound
the admitted shape. Every accepting transition on the earliest source tick
publishes its MATCH before one CLOSE prevents later endpoint rescue. Repetition,
locals, match items and unbounded shapes retain their existing restrictions.

The focused run passes52 cases in each harness:16 new paired cases plus36
L107 migrated/neighbor cases. The NFA compatibility run passes58. Tests check
earliest failure, tied matches and cover aggregation, coincident overlapped
and nonoverlapped handoff, terminal depth64, depth65/unbounded rejection,
overlapping attempts and asynchronous kill/restart. The former L107 two-window
compile-negative now checks a plain-prefix runtime result.

Clock arithmetic, stimulus timing and a vacuous-success test mistake were
corrected during review; failed captures remain in the validation record.
The final run used the combined installed L112/L113 candidate; L113 remains
independently unqualified. No broad or application qualification is inferred.
See [the revision-scoped record](2026-09-15_multi_window_first_match_validation.json)
for exact commands, tool/source fingerprints and captured results.

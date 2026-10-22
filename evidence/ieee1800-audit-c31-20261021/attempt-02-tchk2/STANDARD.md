# IEEE basis and expected Clause 31 timing-check results

The six checks below have the same subclause numbering and window rules in IEEE 1800-2017 and IEEE 1800-2023. Each probe uses `-gspecify` and `1ns/1ns` precision. Times are measured from time zero.

| Check | Clauses/pages (2017; 2023) | Normative rule and stimulus calculation |
|---|---|---|
| `$recovery` | §31.3.5, p. 870; p. 902 | `beginning = timestamp time`, `end = timestamp time + limit`; report if `beginning <= timecheck time < end`. `rst_recovery` rises at t10; `clk_recovery` rises at t11 with limit 3, so t11 is inside `[10,13)` and should report at t11. |
| `$removal` | §31.3.4, p. 869; p. 901 | `beginning = timecheck time - limit`, `end = timecheck time`; report if `beginning < timestamp time < end`. `clk_removal` (data/timestamp event) rises at t20; `rst_removal` (reference/timecheck event) rises at t21 with limit 2, so t20 is inside `(19,21)` and should report at t21. |
| `$period` | §31.4.5, p. 880; §31.4.5, p. 912 | Violation when `timecheck time - timestamp time < limit`. `clk_period` rises at t30 and t36; `6 < 10`, so one report should occur at t36. |
| `$skew` | §31.4.1, p. 873; §31.4.1, p. 905 | Violation when `timecheck time - timestamp time > limit`. `clk_skew_ref` rises at t40 and `clk_skew_data` at t43; `3 > 2`, so one event-based report should occur at t43. |
| `$setuphold` | §31.3.3, pp. 868–869; pp. 900–901 | With positive limits and data first, violation when `(timecheck - setup_limit) < timestamp <= timecheck`; `data_setuphold` at t49 before clock t50 lies in `(47,50]`. With reference first, violation when `timestamp <= timecheck < timestamp + hold_limit`; data at t51 lies in `[50,52)`. Expect one setup report at t50 and one hold report at t51. |
| `$nochange` | §31.4.6, pp. 880–881; pp. 912–913 | `beginning = leading reference edge - start offset`; `end = trailing reference edge + end offset`; report if `beginning < data event < end`. With offsets 0, the standard's example says a data transition while the reference is high violates. `clk_nochange` rises at t60, falls at t64, and data changes at t61, so one report should occur at t61. |

The standard says for `$nochange`: “The $nochange timing check shall report a violation if the data signal changes while clk is high.” For `$skew`, it reports when `(timecheck time) - (timestamp time) > limit`. For `$period`, the report condition is the corresponding difference `< limit`. The same wording and formulas were checked in both editions.

Expected total: 7 reports (one each for recovery, removal, period, skew, and nochange; two for setup and hold within `$setuphold`). The single shared notifier should change 7 times, with final output `N 7 1` from initial notifier value 0.

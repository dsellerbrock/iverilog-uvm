# Clause 39 assertion API probe

The same VPI module is loaded for the main assertion design and its disable variant under `-g2017` and `-g2023`. `$probe39(0)` enumerates all design assertions, prints each full name, and registers success/failure callbacks. `$probe39(1)` performs the same registrations and attempts the standard VPI assertion-disable control before the first clock edge; the probe reports the control result and later callback counts. [`STANDARD.md`](STANDARD.md) records the normative subclauses and callback arguments; [`DEDUPE.md`](DEDUPE.md) records the open+closed issue search. `header-constant-check.c` checks the Annex M header mismatches and missing constants from the follow-up full-header comparison.

Passing the optional integer argument lets the paired variants share the same C module while keeping the control difference explicit in each SV input.

# September 20 merged-baseline restoration

Main `782d951145352ef9423ffb4f6a8957ce86ea625a` merged PR302 at its original
head, omitting the reviewed procedural-selector repair. The generated PR
integration also removed the previously merged PR303 class-scope readiness
change and its regression. Restore those exact source/test changes from
reviewed local checkpoint `e90059a07708cf2a3022255bfce640808178a418`.

The restored compiler and test trees match that checkpoint. Its integrated
local gate passed: legacy 5848 passed, zero failures (2 not implemented,
3 expected failures); VPI108/108; negative148/148; runtime invariants15/15.
Both paired focused suites and112 neighboring tests passed before freezing.
The remaining broad gates are running; this is not full qualification.

The [original review record](2026-09-20_pr_review_repairs.md) retains the
bounded support, source preservation, and outstanding-feature distinctions.
No application sources are changed. Remaining CI jobs must still be inspected;
the user authorizes follow-up PRs for later CI failures.

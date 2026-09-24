# First Icarus L0 case with bundled-BFM and pure-checker copies

`smoke_test_veer` completed **1/1 diagnostic** under explicit
`-gcommercial-unsafe`, with 51 released L0 names unrun. The runner used a
hash-guarded copy of Caliptra's bundled BFM for its delta-cycle
power-good shift and a hash-guarded copy of the pinned SVA file with four
checker predicates made pure. Both changes were confined to disposable
copies; Caliptra and Adams Bridge remained clean at their pinned commits.

The unchanged runtime gate accepted firmware exit 0, simulation exit 0, one
`TESTCASE PASSED` marker, no fail marker, zero error/assertion diagnostics,
zero missing DPI symbols, 633 retired instructions, 4,348 cycles, and 634
trace commits. Compilation had zero Preponed sampling warnings. Tool,
runner, profile, copied-source, patch, and native-vector fingerprints matched
before and after the run; see `summary.json` and
`smoke_test_veer/result.json` for exact hashes and commands.

This is `diagnostic_reset_checker_source_overlay`, **not** a pristine unsafe
compatibility pass or IEEE conformance pass. The pristine unsafe first case
remains 0/1 on 17,863 diagnostics. The next full sweep requires the runner's
named firmware overlays to be isolated per case; the single-case result here
uses the pristine firmware source and is unaffected by that pending fix.

# Open/closed issue dedupe — §16.16

Snapshot: `dedupe-all-issues.json`, fetched with `gh issue list --state all --limit 1000`; 419 issues (292 open, 127 closed). Searched all titles and bodies for `16.16`, `clock resolution`, `inferred clock`, `leading clock`, `default clocking assert`, and `clocking block property`, then checked known neighbors #679 and #710 as the lead requested.

Relevant neighboring issues are distinct:

- #679 (closed): default clocking for sampled-value functions in procedural event controls (§16.9.3), not leading-clock resolution of concurrent assertions.
- #710 (open): missing diagnostics for sampled-value functions when no clocking event can be inferred (§16.9.3), not module-level assertion clock resolution.
- #700 (open): missing `endclocking` matching identifier label (§14.3), unrelated to properties declared within clocking blocks.
- #873 (open): local-variable declaration initialization in a property/sequence; the `leading clock` match is incidental.

No direct §16.16 issue was found in the open/closed snapshot. If a probe finds a gap, compare it again against these neighbors and issue bodies before filing.

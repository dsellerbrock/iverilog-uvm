# Open/closed issue dedupe — time-zero sampled values

Snapshot: `dedupe-all-issues.json`, fetched from `dsellerbrock/iverilog-uvm` with `gh issue list --state all --limit 1000`; 415 issues total (288 open, 127 closed). Both states were searched in titles and bodies for `time.?zero`, `default sampled`, `sampled value`, `Preponed`, `initial value.*assert`, `assert.*initial value`, and `sampling.*initial`.

Related results:

- #709 (open): procedural `$sampled` reads a live value instead of the Preponed sample. It does not describe the sampled value used by a concurrent assertion attempt at time zero.
- #496 (closed): procedural `$past` operand sampling in the Preponed region; different call path and behavior.
- #910 (open): `const'` cast parsing; the current S3d/S3e sources do not use that cast.
- #711/#712: clocking-input/global-clock sampled-value function support; neither addresses the concurrent assertion's default time-zero sample.

No exact duplicate was found. The lead independently confirmed the distinctions and filed [#912](https://github.com/dsellerbrock/iverilog-uvm/issues/912) for this concurrent-assertion time-zero gap.

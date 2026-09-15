# L61 — Runtime class-property increment and decrement

Direct scalar property increments previously returned without updating integral
storage and could abort for real storage. Fixed-array property increments had
the same missing effects. The backend now loads and stores scalar or indexed
property values, captures the receiver before evaluating the index once, and
preserves prefix/postfix values. Invalid indices read the element type default,
perform the arithmetic, and suppress the store. Unsupported destination shapes
produce a target error. IEEE 1800-2017/2023 6.11.2, 7.4.6, 8.4, and 11.4.2
supply the type, array, receiver, and increment contracts.

Root frozen replay: 114/114 paired outcomes (48 baseline, 48 boundary,
six captured receiver, six mutation notification, six const controls).
Permanent harnesses: legacy 2/2, JSON 4/4. Existing neighbors: 21/21.
Evidence: `evidence/runtime-property-increment-assessment/root-frozen/results.json`
and `l61-final/` beneath the same assessment directory. Source review found
balanced object/value stacks and index resources on valid and invalid paths.

Installed SHA-256 values:
- Compiler: `0f6667add55e883ff9752b769528445095f63eb4ceed0f3cf52df34cafcc13d4`
- Target: `41b624bc72b60858fba2ba1fa8c217f0b1c295336e7073f2d82b950044ef2d0b`
- Runtime: `a6788f42934e9bb16a0b1409408c84a776033727ff8aaba8d37c20b269c3bc76`

Locally fast-forwarded into main as `497110d63`. This is the ninth focused feature in the current
batch; broad qualification remains at `c686a4781` until the batch gates run.
DD-029 wide string-array reads are next; DD-030 packed-select increments remain
open. No null-access value, parser expansion, or full property-context coverage
is claimed. No application source or remote branch was changed.

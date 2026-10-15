# `vpip_vec4_to_int64_saturated` word-plane screen

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

The first prototype replaced the per-bit X/Z pre-scan with `has_xz()`. It cut
the converter's inclusive Callgrind count by 45.885180%, but the focused
process fell only 9.654496%, below the screening threshold. A word-plane
follow-up fused X/Z detection with extraction and overflow checks. That is the
candidate in the WP2 worktree.

| Screen | Reference → candidate instructions | Result |
| --- | ---: | --- |
| Initial focused `has_xz()` prototype | 2,342,071,592 → 2,115,956,379 (−9.654496%) | Continue screening; not kept |
| Word-plane focused input | 2,342,072,014 → 1,863,201,596 (−20.446443%) | Passed |
| Fused X/Z word-plane follow-up | 2,342,144,538 → 1,861,170,476 (−20.535627%) | Passed |

The focused follow-up input adds a narrow-Z assertion, so its 0.089-point
difference from the prior variant is not a matched comparison. On the fused
candidate, all 18 sim-hotspots Callgrind outputs matched, and the instruction
deltas ranged from −0.026238% to +0.002218%. Native runs matched all 18
outputs. The 65-bit signed-tail and X/Z edge regression passed on both
installations. Whole-process instruction counts are the screening metric;
`perf stat` instruction events are unavailable on DAN-DESKTOP.

The final candidate needs one deliberate instruction remeasurement after
#593 merges because that PR changes `vvp/vvp_net.h`. Its pinned-base evidence
already clears the 10% target and broad-regression limits. Full PR correctness
gates and exact-head CI remain required.

Detailed results: [`word-plane screen`](wordscan-screen/README.md) and
[`fused X/Z broad screen`](wordscan-screen/fusedxz-broad-20261015/README.md).
The PR retains compact reports, aggregate tables, source/input hashes, and the
focused edge logs. Raw Callgrind profiles, duplicate waveforms, and build
outputs remain in the local revision-scoped evidence archive. The first
focused runner's provenance says 10,000 iterations, but its staged input source
and hash show 100,000; that preliminary run is not the qualifying result.

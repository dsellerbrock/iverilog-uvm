# Constructor-dependent transition endpoints — L110

FOCUSED_TESTED; required broad batch qualification pending. IEEE1800-2017
and2023 19.5.2 and19.11.3.

Transition endpoints can now use the existing constructor-range IR. The full
program resolves per instance, then uses the shared transition NFA. Unsized
merged identities retain term boundaries, repetition mode, chosen count and
values. Named bins count at most once per sample. Unsupported expressions and
invalid/empty/excessive resolved programs fail explicitly without accepting a
shortened recognizer. Existing constant repetition modes are supported;
constructor-dependent repetition bounds remain outside this increment.

The new `.covgrp_dyn_trans` directive preserves old dynamic value metadata.
VVP grammar conflict counts remain14 shift/reduce and5 reduce/reduce. A direct
compatibility replay puts a numeric property after old `.covgrp_dyn_bin`
metadata and runs successfully; the initial ambiguous syntax was discarded.

Both focused harnesses pass16 cases, covering disjoint/overlapping type unions,
instance coverage, named at_least counting, signed cross-zero ranges,
consecutive/goto/nonconsecutive repetition, iff and frozen constructor values,
and invalid/empty/cap failures. Coverage neighbors pass53 legacy and50 JSON.
The runtime-negative fixtures yield before their fatal sentinel so the
scheduled failure can terminate; exact ERROR and nonzero exit remain required.

The original assessment accidentally set both coverpoint weights to zero;
its expected50percent was invalid. The corrected default-weight reducer and
permanent union tests produce exactly50percent in both editions. The original
record is preserved, not rewritten into a passing result.

See the [validation record](2026-09-15_constructor_transition_bins_validation.json)
for commands, hashes, failed candidates, corrected oracle and exact results.
This does not qualify all functional coverage or application workloads.

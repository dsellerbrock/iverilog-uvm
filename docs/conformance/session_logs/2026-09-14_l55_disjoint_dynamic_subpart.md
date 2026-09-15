# L55 — Dynamic writes within disjoint fixed packed elements

IEEE 1800-2017/2023 6.5 uses the longest static prefix to determine overlapping
variable drivers. The original reducer rejects a procedural dynamic subpart of
words[0] even though only words[1] has a continuous driver.

The indexed-lvalue path now reuses L54's exact fixed-prefix proof and carrier
geometry when checking the driven mask. A proven disjoint carrier proceeds
through existing bounded partial-store lowering. Actual overlap and unproven
prefixes retain the conflict diagnostic. No runtime change was needed.

Focused legacy 7/7 and JSON 14/14 pass, including both editions, blocking,
compound, delayed NBA capture, low/high partial selections, both indexed
selection directions, X/OOB bases, continuous neighbor updates, and base/RHS
evaluation counts. Same-carrier overlap is a permanent compile-error test.
L44/L49/L54 neighbors and synthesis controls pass; null compilation passes
both editions. Build/install and root source/test review pass. Frozen evidence
is in `evidence/dynamic-mixed-driver-assessment/l55/frozen-focused-*`.
Earlier test-list typo invocations are retained separately and excluded.

This is the third focused feature after the qualified L43–L52 batch; full
suites remain deferred to approximately ten features. The earlier unpacked
whole-word driver guard remains a separate restriction. Dynamic packed-prefix
writes remain incorrect in the six-case-per-edition next reducer and need
runtime bounds, clipping and single-evaluation preservation.

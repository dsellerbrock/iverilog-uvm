# L54 — Suppress indexed writes through invalid constant packed prefixes

The six-case matrix in
`evidence/dynamic-mixed-driver-assessment/invalid-prefix-writes/` shows writes
through constant out-of-range and X prefixes changing unrelated packed data
in both editions. Blocking, compound and nonblocking assignments all fail;
the final-index and RHS functions each execute once.

IEEE 1800-2017/2023 11.5.1 and 11.5.2 require selection boundaries to respect
the selected packed element. An invalid prefix cannot alias an adjacent
element after flattening. The implementation classifies the original constant
prefixes exactly, before relying on the flattened offset. Valid constant
prefixes retain L49 carrier bounds; invalid ones produce an unknown address
while preserving final-index evaluation. Existing assignment lowering then
suppresses the store. Dynamic or unclassified prefixes are not treated as
proven-invalid constants.

Focused legacy 4/4 and JSON 8/8 pass. Permanent write-bound checks cover
blocking, compound and NBA storage effects; X/Z and exact out-of-range
prefixes; unpacked words with word-index, final-index and RHS evaluation
counts; and valid ascending, nonzero and negative ranges. The original
six-case matrix passes both editions. A separate 128-bit prefix probe also
passes, while retaining existing host-width conversion warnings; it remains
durable evidence rather than host-dependent golden output.

A root testbench drives a no-function DUT through tick 0/1/0 and checks that
its initialized words remain unchanged. Ordinary and synthesized simulation
pass in both editions (`l54/root-invalid-prefix-synth-results.json`). Null
and synthesis compile checks also pass. VHDL generation succeeds but runtime
was not qualified; vlog95 reports its existing unsupported `$signed` lowering.
An earlier shell invocation grouped multiple flags into one argument and is
excluded from compiler evidence; `final-null-synth.log` records the corrected
commands.

Incremental build/install and root review pass. Final focused logs are
`l54/frozen-focused-{legacy,json}.log`. This is the second focused feature
after the qualified L43–L52 batch; full suites remain deferred to the next
approximately ten-feature boundary. Dynamic write prefixes and disjoint
mixed-driver dynamic subparts remain separate DD-022/DD-021 obligations.

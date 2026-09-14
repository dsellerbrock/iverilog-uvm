# L48 — Preserve each packed prefix dimension in indexed reads

For `logic [1:0][2:0][7:0] words`, an indexed read through `words[0][3]`
returned bits from a neighboring element. An unknown middle prefix also aliased
valid data. Both editions fail the original reduced assertions recorded in
`evidence/dynamic-mixed-driver-assessment/prefix-boundary-results.json`.

Final-dimension indexed reads now retain each packed prefix as a nested
`NetESelect`. Each index is normalized against its own declared range before
scaling to the remaining element width. The existing multiplication helper
already widens its operands, so no separate scaling implementation is needed.
Pure packed signals and packed suffixes of unpacked words bypass the older
flattened-address path for this shape. Shorter subarray selects keep their
existing path. The earlier valid-constant-prefix special case is superseded.

IEEE 1800-2017/2023 11.5.1 and 11.5.2 require per-dimension addressing and
invalid-index results appropriate to the selected data type. VVP now evaluates
an immediate unknown select base through its existing variable-select operation
instead of asserting, and casts two-state select results to two-state values.
Index expressions retain their single evaluation, including the final index
when a preceding index is invalid. Real-valued prefixes are rejected.

Focused legacy 2/2, JSON 4/4, and the L46 JSON neighbor 2/2 pass. Null and
synthesis checks pass in both editions; the existing variable part-select bound
negative remains rejected. Logs are `final-l48-*` in the reducer evidence
directory. Root reviewed routing, index normalization, selected types, target
evaluation, and test expectations. This is the sixth focused fix. Full suites
remain deferred to the approximately ten-feature batch boundary. These results
do not qualify packed writes or a full clause.

An attempted focused invocation used `./regress -l ...`; that wrapper discards
arguments and started the broad legacy list. Root terminated it (143) before
completion. The observed output included a `sv_rand_distribution1` mismatch;
the interrupted run is not qualification, and the batch gate must assess the
fresh failing set. Focused runs must invoke `perl vvp_reg.pl <list>` directly.

DD-022 writes remain open: blocking, compound, and nonblocking partial writes
can affect a neighboring packed element. The write correction must preserve
carrier bounds through the lvalue representation and every store consumer,
including partial overlaps and single evaluation. DD-021 mixed-driver rejection
must not be relaxed before those writes are correct.

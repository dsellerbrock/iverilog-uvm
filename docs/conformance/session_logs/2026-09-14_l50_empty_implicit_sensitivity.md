# L50 — Preserve empty implicit sensitivity during synthesis

`always @* output_value = 16'ha520` reads no signals. Elaboration deliberately
replaces it with a permanent event wait with no body. Synthesis classification
then dereferenced that absent body, crashing with exit 139 in both editions
(`synthesis-empty-sensitivity-results.json`).

`NetEvWait::is_asynchronous` now returns false for the absent body. Existing
synthesis handling keeps the process and reports its ordinary unsynthesized
warning. It does not create a constant driver from an unreachable assignment.
`always_comb` retains its body and time-zero marker, so constant combinational
logic keeps its existing synthesis path. The distinction follows IEEE
1800-2017/2023 9.4.2.2 and 9.2.2.2.

The classifier correction exposed a second null-body dereference in the
legacy synthesis tokenizer. A crash stack identifies `tokenize::event_wait`
called by `syn_rules_f::process`. Its statement walk now uses the same null
guard already used by other statement visitors; the grammar source carries
the fix so parser regeneration preserves it. The process remains intact.

Focused legacy 2/2 pass: the runtime control checks dormant X output,
time-zero constant output and ordinary input-driven retriggering, while the
forced-synthesis negative retains its explicit diagnostic. JSON checks pass 4/4 across 2017 and 2023. Full suites remain at the batch boundary.

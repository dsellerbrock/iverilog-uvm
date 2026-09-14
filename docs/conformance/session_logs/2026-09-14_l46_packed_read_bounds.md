# L46 — Packed indexed read bounds and wide runtime indices

IEEE 1800-2017/2023 11.5.1 requires X for out-of-range read bits, preserving
valid bits of partial overlaps. Flattening a fixed-prefix packed element and
its final indexed select into one full-signal select exposed neighboring bits.
The new lowering retains the element as an inner NetESelect. Earlier-dimension
subarray selection remains on its existing path; unknown constant indices
retain the explicit-X path.

Wide-index checks exposed a necessary runtime prerequisite: `%part` truncated
indices to int32, and `%parti` treated unsigned high bits as signed. Both now
share overflow-safe X-padding clipping; computed indices reuse the existing
exact-or-saturating conversion. Saturation outside int64 is safe because such
magnitudes are outside the supported vector width. No runtime check is disabled.
Constant folding no longer converts a select base to host long when its carrier
is not constant; this removes a platform-dependent warning without changing
constant evaluation.

Focused legacy 1/1 and JSON 2/2 pass. Coverage includes both indexed directions,
partial overlaps, ascending/nonzero ranges, multiple fixed prefixes, dynamic
single evaluation, X/Z, and 32/64/128-bit indices. Null-target and synthesis
smoke pass both editions. Existing illegal variable part-select bounds are
rejected in both editions; L44 JSON neighbors pass 4/4. Root also verified the
nested wide formatting case in both modes. Durable logs are under
`evidence/dynamic-mixed-driver-assessment/final-l46-*`, with separate root
neighbor and formatting results. Root reviewed expression, folding and runtime
paths; `git diff --check` passes.

This is feature four of the approximately ten-feature batch. Broad suites have
not been completed. An attempted `regress --help` started about twenty default
checks before its output pipe closed; those results are not used for qualification.

DD-022 writes and invalid earlier prefixes remain open; DD-021 mixed-driver
restrictions remain unchanged. DD-023 records the distinct one-dimensional wide
constant formatting case. Focused success does not imply full clause coverage.

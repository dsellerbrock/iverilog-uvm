# L62 — Wide fixed string-array reads

The string-array load opcode narrowed native addresses to unsigned32 before
checking bounds and ignored the index converter overflow flag. It now checks
all invalid flags and native signed bounds before converting a valid address.
Independent review also found unsigned all-ones indices wrapping during declared
range normalization. The shared unpacked normalizer now zero-extends unsigned
indices before signed canonical arithmetic, preserving the mathematical value.
This also corrects integral and real sibling reads. Existing storage resolution
and the shared index converter are retained.

IEEE 1800-2017/2023 7.4.6 and Table7-1 require invalid unpacked-array indices
to read the element-type default: empty string for string arrays. Invalid writes
perform no operation. Source indices remain integral values with their declared
signedness; internal normalization must not wrap them onto valid storage.

Root candidate review initially passed16/20, exposing unsigned-negative-range
aliases; the final normalized candidate passes36/36 paired checks (original4,
module matrix8, automatic matrix8, typed sibling reads8, invalid stores8).
Evidence: `evidence/runtime-string-array-index-assessment/root-normalized/results.json`.
No oracle was weakened to accept the original alias.

Permanent regression review and local integration pending. This will be the
tenth feature in the batch, followed by the seven full qualification gates.
The prior broadly qualified baseline remains `c686a4781`.

Additional signedness controls:32/32 paired int/logic/real/string checks at
8/32/64/128-bit index widths preserve signed -1 access while rejecting unsigned
all-ones values. Evidence: `signedness-widths/results.json` beneath the assessment.

Final frozen replay:68/68 root checks, permanent legacy1/1 and JSON2/2,
four existing neighbors. The direct permanent `ints[index] !== 0` check also
requires declared two-state conversion immediately after the generic vector
array load; assignment into an int temporary alone can hide this requirement.
The target now emits that conversion before resizing the loaded value.
Final evidence: `root-final/results.json` and `l62-final/`.
Compiler SHA: `b99ccb5838ab074a1d97ce876f39039cd753392b5c83008b25f6aff579eedec8`.
Target SHA: `e3b1a4042fae5d4d49268f91679e8e057534aa15fd6871ae145133dbccad58c3`.
Runtime SHA: `65baa472d97e06f56ae30a22a51250adfa9f13404f9ab6ccb0dc96fef44d0488`.

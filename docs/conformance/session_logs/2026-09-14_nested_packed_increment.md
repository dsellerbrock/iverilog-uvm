# L71 — Nested packed increment/decrement expressions

IEEE 1800-2017/2023 11.4.1, 11.4.2 and 11.5.1 govern the selected arithmetic and packed bounds. Both editions previously rejected nested packed increment expressions rooted in a scalar packed signal, including a partially overlapping selection of a packed array element.

The target now captures each retained packed carrier and the final index once, reads through each bound, and uses existing dynamic clipping and partial stores to write back only overlapping bits. Arbitrary retained depth and scalar function-return storage are supported. Unsigned indices are checked at full width; the original two-state destination type survives implicit conversion unwrapping. Nested selections rooted in unpacked arrays or class properties remain separate work.

The corrected candidate passes six permanent cases in each legacy/JSON harness and 36 selected-update neighbors. Tests cover three-dimensional carriers, automatic function returns, partial overlap, wide invalid indices, two-state unknown-index prefix results and readonly rejection. Initial oracle, conversion-opcode and gold-path failures are preserved under `evidence/parallel-batch-l71-l72`; they are not qualification. A proposed additional runtime opcode was removed after review found existing clipping sufficient for these cases. A negative-parent intermediate part-select probe aborts earlier in elaboration; its syntax/legality needs separate assessment before implementation scope is assigned.

The [validation record](2026-09-14_nested_packed_increment_validation.json) fingerprints the target and mixed installed compiler/runtime used for these focused checks. Broad batch qualification remains pending.

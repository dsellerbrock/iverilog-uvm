# L67 — Packed-select expression increment/decrement

The installed L66 compiler reproduced DD030 in both IEEE editions: matching-width bit/part prefix and postfix expressions reached vector arithmetic with the wrong width and aborted. Wider result contexts also rejected legal scalar operands as unsupported slices.

IEEE 1800-2017/2023 11.3.6, 11.4.1 and 11.4.2 require the assignment result type, selected update, and single evaluation of an index. The elaborator now uses the operand width for the update and preserves statically folded invalid selection identity. The target captures the selected base once, computes at selected width, stores only that selection using existing bounds/validity machinery, and sizes the yielded value for its context. Scalar function-return selections use the existing return-slot load/store paths.

The evidenced scope is integral selections of scalar packed signals, including two-state/four-state bits, constant/dynamic bit and part selects, prefix/postfix increment/decrement, result contexts, and invalid/partial out-of-bounds behavior. Selected array/property destinations and nested selects requiring an inner carrier boundary remain explicit target errors; this does not claim all increment destinations.

The first root replay passed 36/36 paired outcomes with unchanged installed artifact hashes (preserved in `candidate-first/`). Neighbor regressions pass 5/5 legacy and 10/10 JSON. Evidence: `evidence/dd030-current-assessment/candidate/results.json` and `neighbors-*.log`. Independent review found no concrete defect. Four additional paired controls cover function-return selections and high-bit carriers with widened scalar contexts; two root controls reject unsigned 128-bit index aliases/overflow. All six pass. Permanent regressions pass 8/8 in each harness. Final-build neighbors pass 5/5 legacy and 10/10 JSON, and L66 return JSON regressions pass 8/8.

During oracle review, the original partial-out-of-bounds postfix witness incorrectly expected all X as its returned value. For old carrier 8'haa and selection [6+:4], the returned old value is xx10, while increment arithmetic yields xxxx and writes X only to the in-range carrier bits. The original source and hash are preserved under `review/baseline-history`; the correction preceded candidate replay and is explained in `partial-oob-oracle-review.txt`.

This is a focused feature checkpoint in the batch after L64. Broad qualification remains pending the user-requested batch cadence; the L64 seven-gate record does not qualify these newer changes.

A later scalar function-name context witness exposed an unresolved signal and runtime crash in the whole-signal store path. Both prefix and postfix stores now use the existing return slot for those scalar destinations. The rebuilt final candidate passes 54/54 paired outcomes, including the complete earlier matrix, function-return contexts, unsigned128 index overflow, and explicit unsupported-shape controls, with stable driver/compiler/runtime/target hashes in `candidate/results.json`.

The compact [validation record](2026-09-14_packed_select_increment_validation.json) records source and installed artifact fingerprints for this focused checkpoint.

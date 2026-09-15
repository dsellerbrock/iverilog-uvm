# L68 — Packed increment/decrement within fixed-array elements

The L67 compiler rejected expression-valued packed bit/part updates inside fixed unpacked-array elements. The target already had partial array stores, but selected-expression lowering admitted only scalar signal carriers. Constant-folded invalid selections also lost the array word identity needed to suppress the correct write.

The target now captures the flattened word and packed base once, preserves both validity flags, loads the selected word, computes at the packed selection width, and uses the existing partial array store. Invalid constant selections retain their word expression during reconstruction. No runtime opcode or array storage ABI changes were needed.

Authority: IEEE 1800-2017 7.4.6 and IEEE 1800-2023 7.4.5 for array indexing/defaults; both editions 11.4.2 and 11.5.1 for increment and packed selection. The paired scope includes constant/runtime selectors, nonzero and descending ranges, multidimensional word indices, result contexts, neighbor preservation, invalid selections, and automatic/function-return arrays. Class-property receivers and inner-carrier boundary support remain separate gaps.

The first root candidate passes 26/26 paired outcomes with stable driver/compiler/runtime/target fingerprints in `evidence/array-packed-incdec-l68/candidate/results.json`. Baseline failures and source hashes remain in `baseline.json` and `review/`. The function-return array baseline aborted while the unsupported path evaluated its fallback; the admitted direct array load/store path passes the same source without an extra return-transport change.

Independent review found no concrete defect. Two additional paired outcomes cover two-state word/packed validity, partial out-of-bounds conversion, and single evaluation. Permanent regressions pass 8/8 in each harness; L67 neighbors pass 8/8 in each harness and array/property neighbors pass 10/10 JSON. The [compact validation record](2026-09-14_array_packed_increment_validation.json) owns the source/artifact fingerprints. This is the fourth focused feature in the batch after L64; broad qualification remains pending the user-requested batch cadence.

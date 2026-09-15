# L69 — Packed increment/decrement within scalar class properties

L68 still rejected expression-valued packed bit/part updates when the carrier was a scalar integral class property. The target recognized only signal carriers for a selected update even though ordinary partial property assignments already supplied the required receiver capture and read-modify-write operations.

The target now captures and null-checks the property receiver before evaluating the packed base, loads the whole property, evaluates the base once, computes at the selected width, and stores through the existing signed or unsigned partial-property opcode. Rebinding the source handle while evaluating the base therefore does not redirect the write. No runtime opcode, IR, or property storage change was needed.

The paired scope covers bit and part prefix/postfix updates, wraparound and result contexts, receiver rebinding, nested and inherited receivers, adjacent-bit preservation, four-state and two-state invalid/partial-overlap behavior, wide signed and unsigned offsets, and readonly rejection. Selected unpacked-array properties remain explicitly unsupported.

The root candidate passes 26/26 paired outcomes in `evidence/class-packed-incdec-l69/candidate/results.json`. Permanent regressions pass 10/10 in each harness; raw streams are `permanent-legacy.log` and `permanent-json.log`. The [compact validation record](2026-09-14_class_packed_increment_validation.json) owns artifact and source fingerprints. Broad batch qualification remains pending and this focused checkpoint does not qualify all of Clause 11.

IEEE 1800-2017 and 1800-2023 11.4.1/11.4.2 govern single index evaluation and blocking increment/decrement behavior; 11.5.1 governs packed-select bounds. Null member access is illegal with indeterminate results under 8.4 and is not part of the semantic claims. Neighboring JSON checks passed: L67 8/8, L68 8/8, whole-property increments 4/4, partial-property offsets 8/8, and signed property compound assignments 2/2. Exact commands and raw logs are retained beside `neighbors.json`.

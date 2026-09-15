# Constant fixed-array string-character increment — L101

IEEE 1800-2017 and 1800-2023 6.16,11.4.2,13.4.3. FOCUSED_TESTED; required broad batch gates remain pending.

The constant evaluator now resolves the exact local fixed-array word before evaluating the character selector, once each. It reuses the existing slot resolver and byte-update path, then extends the signed byte result to the unary expression width. All four operators preserve pre/post results, invalid-word discard, character int32 conversion, zero-byte write suppression and automatic frames.

Paired tests check constant and runtime behavior, shared selector side effects, selected-byte and whole-word values, signed and widened results, bounds and locality diagnostics. The bounds reducer runs both folded and runtime forms. An older L96 scalar negative gold is refreshed to the specific input-only constant-function diagnostic; its other diagnostics and four-error total remain intact. This diagnostic correction is not another feature.

Failed candidates and traces are retained locally. Removing the selected-byte width guard was disproved and reverted; selected-byte reads were restored after evaluation-tree tracing identified the result-width defect. Mixed integral/string-literal equality and const local fixed-string-array initialization are separate unqualified discoveries, not accepted limitations of the tested update behavior.

[Revision-scoped validation](2026-09-15_constant_array_character_increment_validation.json) records source/artifact hashes and results. Raw logs remain under `evidence/batch-20260915-after-l95`.

# L65–L74 compiler batch qualification

Ten bounded compiler fixes are integrated in this batch. The semantic source ends at `374318731`; the frozen qualification checkout is `e259716513ac2bf3bec341abc9c64e127d260780`. The coordinator reused two implementation agents with disjoint source ownership, integrated focused fixes, then ran the broad required gates once for the ten-fix candidate.

Scope and focused evidence remain in the individual records:

- [L65: multiple prefix indices in constrained fixed-array reductions](2026-09-14_constraint_multiprefix_reductions.md).
- [L66: typed real/string array return elements](2026-09-14_typed_array_return_elements.md).
- [L67: packed-select increment/decrement expressions](2026-09-14_packed_select_increment.md).
- [L68: selected fixed-array words](2026-09-14_array_packed_increment.md).
- [L69: selected scalar class properties](2026-09-14_class_packed_increment.md).
- [L70: selected fixed-array class-property words](2026-09-14_class_array_packed_increment.md).
- [L71: retained nested packed selections](2026-09-14_nested_packed_increment.md).
- [L72: constant-function string character reads](2026-09-14_constant_string_character.md).
- [L73: constant-function character writes and signed character metadata](2026-09-14_constant_string_character_write.md).
- [L74: runtime scalar string character compound assignments](2026-09-14_runtime_string_character_compound.md).

The [qualification JSON](2026-09-14_compiler_batch_l65_l74_qualification.json) is authoritative for counts, source identity, commands and artifact hashes. Integrated legacy/VPI/negative/runtime gates, JSON, real-DPI UVM, SVA NFA, release smoke, make check, and frontend scenarios all passed. All 14,995 tracked-file fingerprints and the six installed-artifact fingerprints remained stable; frontend relocation restored the installation. The manifest audit found all new registrations exactly once.

The UVM suite uses its existing `-g2012` invocation. Its result does not establish full UVM qualification in both newer editions. Release results are smoke checks. No fresh unmodified OpenTitan/Caliptra application replay is claimed, and the full IEEE/UVM/formal mission remains open. Ten bounded fixes are not a completion percentage for the language. Initial focused failures and corrected test expectations remain preserved in the raw evidence; no broad failure was waived.

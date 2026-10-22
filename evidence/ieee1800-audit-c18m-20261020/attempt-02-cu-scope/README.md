# IEEE 1800 external constraints and inheritance, compilation-unit scope

- Corrected follow-up after job 3476: classes/external blocks now share compilation-unit scope; the original module-scope probe is preserved in attempt 01.
- Standards: IEEE 1800-2017 §§18.5.1–18.5.2, pp.510–511; IEEE 1800-2023 §§18.5.1–18.5.2, pp.529–531.
- Main probe covers C/C_P3, B, D, DV, E, W. n1–n6 compile-only rules are checked at compilation-unit scope and run if the compiler accepts them. MOD and PKG separately test valid module- and package-scope external blocks.
- Each compiler/runtime process has a 30-second process-group timeout. Inputs, timeout helper and run script hashes are in `input/SHA256SUMS-input.txt`.
- Open+closed issue searches are in `dedupe-open-closed.txt`.

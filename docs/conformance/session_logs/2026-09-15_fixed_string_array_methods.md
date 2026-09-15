# L99 — Fixed string-array mutating methods

IEEE 1800-2017 and 1800-2023 6.16, 7.4 and 13.4.3 require a mutating string method to update its selected variable, including a local fixed-array element in constant evaluation. Previously constant calls aborted and dynamic runtime receivers updated a temporary string.

The evaluator now reuses the existing local word-slot resolver. The VVP target captures the canonical receiver index before evaluating explicit arguments and passes an existing writable array-word handle. The array implementation writes string values and discards invalid writes. Full-width invalid indices remain invalid rather than aliasing word zero; constant out-of-range receivers retain their identity so arguments still evaluate once.

The [validation record](2026-09-15_fixed_string_array_methods_validation.json) fingerprints the tested source and installed artifacts. Paired tests verify all six methods, receiver/argument ordering, descending and nonzero bounds, signed narrow and 64/128-bit/X indices, zero-byte behavior, untouched neighbors and recursive automatic frames. A zero-based integral `$sscanf` output control exercises the shared VPI bounds guard. External constant receivers and invalid actuals remain rejected. Existing scalar negative golds retain their original non-local-reference diagnostic and add the slot resolver's precise assignment diagnostic.

Focused and neighboring harnesses pass; broad batch qualification remains pending. Adjacent general VPI real-output and nonzero-range handle observations are unqualified and do not expand this implementation claim.

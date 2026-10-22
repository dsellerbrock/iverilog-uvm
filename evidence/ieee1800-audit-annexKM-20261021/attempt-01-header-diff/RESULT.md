# Results — Annex K/M public-header comparison

The macro comparison used the normative code listings from both editions and the active macro tables produced from the pinned Icarus headers. `sv_vpi_user.h` includes `vpi_user.h`, so Annex M's extension definitions were checked against the combined included interface. The report lists every differing value, missing standard macro and Icarus-only macro in `comparison.txt`.

| Standard listing | Standard VPI names | Same-name value differences | Standard names missing | Icarus-only names |
|---|---:|---:|---:|---:|
| Annex K, 2017 vs `vpi_user.h` | 452 | 0 | 257 | 1 |
| Annex K, 2023 vs `vpi_user.h` | 455 | 0 | 260 | 1 |
| Annex M additions, 2017 vs included Icarus interface | 386 | 2 | 345 | 10 |
| Annex M additions, 2023 vs included Icarus interface | 399 | 2 | 358 | 10 |

The Annex M value mismatches are `vpiAssertion` (standard 744, Icarus 686) and `vpiModport` (standard 606, Icarus 603), in both editions. Annex K has no same-name value mismatch. Annex K adds three names in 2023 (`vpiInterconnect`, `vpiNettypeNet`, `vpiNettypeNetSelect`); Annex M adds thirteen names in 2023. No shared numeric value changes between editions; Annex M re-expresses `vpiConcurrentAssertions` as the alias `vpiConcurrentAssertion`, which still resolves to 740.

A compile-time probe against the copied pinned Annex K header exited 1 with the expected missing-name diagnostics for `vpiAlways`, `cbAssign` and `vpiWidth`. Compiler: Apple Clang 21.0.3. The initial attempt lacked the header dependency `_pli_types.h` and failed before reaching those checks; the dependency was copied from the same pinned toolchain and the corrected probe produced the three intended diagnostics in `header_annex_k_probe.out`.

This establishes public macro-table gaps and value mismatches; missing names alone do not establish absent runtime support. The Annex M assertion finding is tracked in #883, and its runtime disable behavior in #884. The Annex K header gap has no matching issue in the open+closed dedupe searches recorded in the assertion probe's `DEDUPE.md`; the audit lead owns classification and issue filing.

The full Annex M discrepancy table was posted to [#883](https://github.com/dsellerbrock/iverilog-uvm/issues/883#issuecomment-6311027142), following the lead's handling rule. The lead has since filed [#885](https://github.com/dsellerbrock/iverilog-uvm/issues/885) for the Annex K gap. Its explicit final classification is still pending, so the matrix row remains `PROBED — LEAD PENDING` and now links to #885.

## Provenance

- Toolchain source commit: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
- DAN-DESKTOP header copies match: `vpi_user.h` SHA-256 `7de639217c343bf9d077545e6283fafafc18afa5cfab22d292e6787ab28f7268`; `sv_vpi_user.h` SHA-256 `7d18188bb855ea83dea8ba0f8c64a411023ba1edceef872ecf8173fedb0b1ba9`.
- Standard extraction: 1800-2017 Annex K pages 1269–1285, Annex M pages 1289–1298; 1800-2023 Annex K pages 1307–1323, Annex M pages 1327–1337.

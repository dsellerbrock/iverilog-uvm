# Associative `find_last_index()` qualification — 2026-10-07

## Result

IEEE 1800-2017/2023 §7.12.1 requires index locators on associative arrays to
return the declared index type, and `find_last_index()` to return the last
matching actual key in associative key order. The compiler now starts at the
last key and walks predecessors, stopping on its first predicate match. The
typed result queue contains the actual key; empty arrays and no matches return
an empty queue. Wildcard-index arrays remain rejected.

## Reproducer and scope

The permanent paired test is `ivtest/ivltests/sv_assoc_find_last_index.v`.
Before the fix, the source-built Fix30 compiler rejected every call with
`find_last_index() on associative arrays is not yet implemented` under both
`-g2017` and `-g2023`.

The Fix30 baseline image hashes were `iverilog`
`36167f4671b3cb3616dae40e800be83a238e10301cc4516d27c69ca98d486e15`, `ivl`
`20cdb1517b08fa2a3ea249c9cd4b37c6dc6b64a13470b5e77fe9fce705b3ea0b`, `vvp`
`158fb79e1624083da370d5a176bf85f3ef96e01b91e4c75279af8a68309638b1`, and
`vvp.tgt`
`62eb7f143e93f559affb415c929add856858f111f357b3696c7e843acc7866e8`.

The test covers multiple matches with a nonmatching key between them, signed
integer keys, string keys, empty arrays, and no matches. The tested key types
are the integral and string types already supported by the associative
`find_index` path. Wildcard and other unsupported key types are not expanded.

## Implementation

`elab_expr.cc` routes associative `find_last_index()` through the existing
keyed locator helper. `tgt-vvp/eval_object.c` uses VVP's existing `last` and
`prev` associative-array operations for reverse traversal. Existing forward
`find_index()` and `find_first_index()` behavior is retained.

## Validation

The incremental source build completed successfully with the repository's
configured Homebrew Bison, Z3, and libffi paths. Its warnings are the existing
C++20 bit-field/unused-parameter warnings plus the pre-existing nested-comment
warning in `tgt-vvp/eval_object.c`.

Strict focused checks passed:

- JSON/VVP: 8/8 under paired `-g2017` and `-g2023`.
- Legacy: 8/8 under paired `-g2017` and `-g2023`.

Both lists include this regression, the existing associative `find_index()`
and `find_first_index()` neighbors, and wildcard-index rejection. No broad
regression suite or OpenTitan corpus was run.

Source-built image SHA-256:

| Artifact | SHA-256 |
|---|---|
| `iverilog` | `36167f4671b3cb3616dae40e800be83a238e10301cc4516d27c69ca98d486e15` |
| `ivl` | `7b54baa83ea1a21a5748d54f71230359ec0542f969a29a1a32844edf85f9aa47` |
| `vvp` | `158fb79e1624083da370d5a176bf85f3ef96e01b91e4c75279af8a68309638b1` |
| `vvp.tgt` | `bb665802b4325b5c001f78dc55b68718e9ea7d6033f251578a9393ab3a79df98` |

The local authoritative IEEE 1800-2017 PDF has SHA-256
`12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`; the
IEEE 1800-2023 PDF has SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.

# Associative `find_first_index()` — Fix 30

Fix 30 implements associative-array `find_first_index()` for integral and
string keys in both IEEE 1800-2017 and 1800-2023 modes. It walks the actual
associative keys, returns a fresh queue with the declared key type, and stops
at the first matching key. It does not return a positional ordinal.

## Standard and baseline

IEEE 1800-2017 and 1800-2023 §7.12.1 say array locator methods operate on
unpacked arrays. Index locators return a queue of `int`, except associative
arrays return a queue of their declared index type; wildcard-index associative
arrays are excluded. For `find_first_index()`, associative first/last ordering
uses the key returned by the associative array's `first()`/`last()` method.

The pre-fix compiler rejected the valid reducer
`ivtest/ivltests/sv_assoc_find_first_index.v` under strict `-g2017` and
`-g2023` with `find_first_index() on associative arrays is not yet implemented`.
The corresponding baseline invalid-form neighbor now checks rejection of
wildcard-index arrays.

Official local reference PDFs:

- IEEE 1800-2017 PDF SHA-256: `12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`
- IEEE 1800-2023 PDF SHA-256: `2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`

## Implementation and checks

The existing keyed `find_index` elaboration/runtime path is reused. The VVP
loop appends the actual key, then exits on the first predicate match. Tests
exercise ordered signed integer keys, string-key order and result typing,
multiple matches, no match, and an empty associative array.

From `iverilog-uvm/ivtest`:

```sh
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  python3 vvp_reg.py --strict regress-assoc-find-first-index-vvp.list
PATH=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm/local-install/bin:$PATH \
  perl vvp_reg.pl --strict regress-assoc-find-first-index-legacy.list
```

Results: **6/6** strict JSON/VVP and **6/6** strict legacy. Both lists include
the existing associative `find_index` tests and wildcard-index rejection.
`git diff --check` passes. No full suite or OpenTitan corpus was run.

Source-built image SHA-256:

| Tool | SHA-256 |
| --- | --- |
| `iverilog` | `36167f4671b3cb3616dae40e800be83a238e10301cc4516d27c69ca98d486e15` |
| `ivl` | `20cdb1517b08fa2a3ea249c9cd4b37c6dc6b64a13470b5e77fe9fce705b3ea0b` |
| `vvp` | `158fb79e1624083da370d5a176bf85f3ef96e01b91e4c75279af8a68309638b1` |
| `vvp.tgt` | `62eb7f143e93f559affb415c929add856858f111f357b3696c7e843acc7866e8` |

## Boundary

The implementation covers the non-wildcard integral and string key types
already supported by associative `find_index`. Wildcard indices remain
rejected as required. Other associative locator methods and unsupported key
types remain open; this does not close §7.12.1 or clause 7.

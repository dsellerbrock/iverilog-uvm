# IEEE 1800-2023 array-method index argument — 2026-10-07

Fix 35 adds and edition-gates the optional array-method `index_argument`.
The regression exercises the property form (`item.position`) against a class
element with a real `index` property, associative string-key lookup, and
`sum`, `min`, `max`, and `unique_index` `with` expressions.

## Results

- `make -j4`: pass.
- `make install`: pass.
- New focused legacy list: 2/2 (`-g2023` runtime and strict `-g2017` rejection).
- New focused JSON/VVP list: 2/2.
- Adjacent 2023 map legacy list: 4/4.
- Adjacent 2023 map JSON/VVP list: 4/4.
- No broad regression or OpenTitan corpus was run for this change.

## Reproduction

From `ivtest/`:

```sh
PATH="../local-install/bin:$PATH" perl vvp_reg.pl regress-array-index-argument-legacy.list
PATH="../local-install/bin:$PATH" python3 vvp_reg.py regress-array-index-argument-vvp.list
PATH="../local-install/bin:$PATH" perl vvp_reg.pl regress-array-map-2023-focus-legacy.list
PATH="../local-install/bin:$PATH" python3 vvp_reg.py regress-array-map-2023-focus-vvp.list
```

The installed executables were built from source revision
`82d86e1c654008b85609135727d27d2fafa67306` plus the working-tree changes:

| Executable | SHA-256 |
| --- | --- |
| `iverilog` | `f646fa5eaaf615b89fdd508c60ac4bff6a38e795197b76100b7da6c8fcdd0aa7` |
| `ivl` | `5418cedb693ff35af7b9f500f42b70b9f4696c277012a07b1c36402502ab3ecf` |
| `vvp` | `ec9bea6ad26b84556f8bc800b1176f884ef0a141f47754e8ed1bcee9eebe4d13` |

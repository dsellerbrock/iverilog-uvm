# Result — imported open-array ABI

All three existing tests compiled, linked, and ran successfully under both
IEEE editions in Slurm job 3565 on DAN-DESKTOP. Each individual command had a
30-second timeout. The pinned compiler is `cc25756d1` (`iverilog` SHA-256
`1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp`
SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`):

| Test | 2017 | 2023 | Checks |
| --- | --- | --- | --- |
| `m10_dpi_openarray_test` | PASS | PASS | 16/16 |
| `m10_dpi_open_array_bounds_test` | PASS | PASS | bounds, direction, traversal, element size, 2-D dynamic shape |
| `m10_dpi_open_array_layout_range_test` | PASS | PASS | ascending/descending declared bounds, indexed access, out-of-range null |

Every compile, C link, and simulation returned 0 in both editions. Raw stdout,
stderr, timing, host and toolchain metadata, hashes, and exact input copies are
in [`remote-3565/`](remote-3565/). The probe does not cover every legal
open-array element type or every rank/layout combination.

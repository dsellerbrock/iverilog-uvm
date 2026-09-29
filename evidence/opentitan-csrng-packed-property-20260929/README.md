# CSRNG packed class-property index — 2026-09-29

The frozen 49-target OpenTitan corpus reported a CSRNG runtime abort at `class_type.cc:1181`: `idx < array_size_`. In `cmd_flag0_previous[app]`, `app` selects an element of a packed enum array stored in one class-property slot. The old compiler instead treated `app` as another property-slot index. Paired IEEE 1800-2017/2023 reducers show the old assertion and the analogous write error in `focus/precompiled-red-green.json`.

The final compiler routes packed class-property reads and writes through the packed-select helpers, preserves the enum element type and two-state conversion, and checks each packed dimension so an invalid inner index cannot alias an adjacent element. It preserves silent X/Z selections and rejects a REAL index before logic conversion. A narrow proof accepts bounded dynamic inner ranges that are wholly in bounds, including the released UVM nested-slice shape; unproven crossing ranges still fail closed. Matching arithmetic widths avoid an assertion on nonzero and wide declared bounds, and ascending indexed reads use the same direction normalization as writes. The paired 2017/2023 permanent controls cover those cases. Exact partial clipping for an arbitrary dynamic inner range remains [DD-103](../../docs/conformance/DISCOVERED_DEBT.md#dd-103--exact-clipping-for-a-dynamic-inner-packed-class-property-range).

## Final image and validation

The installed `ivl` SHA-256 is `7427219cfcf964d35119fb738f237596083f41aa3214219bf6a24071c37c5013`; `vvp` is `5b9ed7a8ed8006a998b55c0bc42d035aa99ddeb9c1b3495fd0b4651cf23600c3`. Focused controls passed 28/28 JSON and 16/16 official legacy; their sources, logs, and hashes are under `focus/final-7427219c/`. The final exact-image gates passed:

| Gate | Result |
| --- | --- |
| Full JSON, four shards | 4,147 run, 0 failed |
| Real-DPI UVM, four workers | 362 passed, 0 failed, 0 skipped |
| Full legacy | 6,903 total: 6,898 passed, 0 failed, 2 not implemented, 3 expected failures |
| VPI including PLI1 | 140/140 |
| Negative | 154/154 |
| `make check` | PASS |

`gates/final-7427219c/summary.json` records the counts and SHA-256 of every archived raw log. The closed legacy session was 32179.

The selected CSRNG replay on a disposable exact-hash-overlaid copy of pinned OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127` is **PASS** under the `commercial-unsafe` runtime compile profile. Setup, compile, and runtime exited zero; the compile had zero hard errors and zero semantic debt. Runtime had a pass banner, zero errors/debt, and took 92.528 seconds with a peak physical footprint of 4,076,064,032 bytes under a 6 GiB physical-memory guard and 1,800-second timeout. See `selected-742-6g/result.json`, `summary.json`, and `logs.tar.gz` for the exact row, compiler fingerprint, and raw setup/compile/DPI/runtime logs.

## Earlier candidates and corpus boundary

The final image's first selected attempt under a 4 GiB guard stopped at that memory limit; `selected-742-4g/` preserves the result and logs. The 6 GiB replay resolved this resource limit and passed. Candidate `7c47607b` passed a separate selected replay in 115.967 seconds under 4 GiB (`selected-final/`) but failed one real-DPI UVM bounded-slice test and had two stale combined REAL-index legacy golds; exact gate logs remain under `gates/candidate-7c47607b/`. The two golds were corrected and passed focused 2/2. The earlier `217a152a` focused stage exposed a compiler assertion on a tiny high-based selector; `focus/dynamic-bound-focused-evidence.json` remains as that intermediate record. Initial failed/interrupted logs remain under `gates/initial/`.

The completed **23 PASS / 49** OpenTitan corpus is an immutable result from an earlier compiler image. The selected final-image CSRNG PASS does not change that aggregate count; a new 49-target corpus would be needed for a new aggregate. Caliptra was not run for this ticket.

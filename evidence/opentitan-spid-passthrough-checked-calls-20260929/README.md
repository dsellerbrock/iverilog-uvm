# SPI passthrough checked-call source patch

The selected `readbasic` row was DEBT after the matrix learned its official `+TESTNAME=readbasic`: the released testbench ignored eight `randomize()` returns and two `$value$plusargs()` returns, and initialized an implicit-static transaction local. A [named source patch](../../docs/conformance/release_overlays/opentitan/spid_passthrough_checked_calls.patch) checks every return, rejects missing/unknown test names, and makes that local automatic. It applies only to a disposable copy with the before-hashes in `source-hashes.json`; applying it to a two-file copy reproduces both after-hashes exactly. The pinned OpenTitan source remains unchanged.

- Paired strict 2017/2023 focused controls (`focus-result.json`, `focus/*.sv`) cover successful and missing `+TESTNAME`, failed randomization before field use, and static versus automatic local lifetime. All 12 compile/runtime cases meet their expected outcomes.
- Fresh one-core matrix on the patched copied source: **PASS**. Compile exit 0 with zero semantic debt; VVP exit 0 in 4.090 seconds with one `TEST PASSED CHECKS`, zero runtime errors/debt, and no 2 GiB footprint-cap or 120-second timeout hit. The `readbasic` path compares the 131-byte second read against its stored mirror. See `matrix-result.json` and the raw compile/runtime logs.
- Missing and unknown `+TESTNAME` controls each exit 1 with the expected fatal message, no pass banner, and no guard hit (`negative-selectors.json`).
- The other two official smoke cases, `addr_4b` and `wel`, each exit 0 with one pass banner and zero runtime errors/debt under the same guards (`neighbor-smokes.json`). Their logs show address-mode commands and ten WEL commands respectively.

This is a selected copied-source result with prior named compatibility overlays and `-gcommercial-unsafe`. The frozen 49-target corpus remains **23 PASS / 49**; no full corpus was rerun.

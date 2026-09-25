# OpenTitan SRAM indexed dynamic-array slice

Pinned Earlgrey-PROD-M6 `sram_scrambler_pkg.sv` (SHA-256
`c2ac433e6bd4d097e148a424dc440d6c7a6fe6dd9f617c839b3877866e788f61`)
reads `logic[]` with `[i*8 +: 8]` at lines 278 and 332, then writes that
eight-element slice at lines 280 and 334. The private class-member candidate
advances both `otp_ctrl_sim` and `chip_sim` to these four hard errors; neither
application has a clean compile or DV runtime.

The local IEEE 1800-2017 §7.4.6 and 1800-2023 §7.4.5 allow a variable slice
position with constant size, keep an unpacked slice unpacked, and give an
invalid or X/Z index its element default on read and no operation on write.
Both editions' §7.6 require equivalent element types, equal source and target
counts for a slice target, left-to-right correspondence, and resizing of a
whole dynamic-array target. A dynamic source of the wrong live count assigned
to a slice requires a runtime error and no write. The 2023 text additionally
states explicitly that a slice left-hand side is one assignment. Local PDF
hashes and exact commands are recorded in [result.json](result.json).

The eight new `ivtest/ivltests/sv_dynamic_array_indexed_slice_*.v` sources keep
the behaviors separate. `read` checks a side-effecting base once, `+:` and
`-:` order/count, partial out-of-range X values, and an unknown-base default.
`write` checks a side-effecting base once, selected-element order, untouched
neighbors, partial out-of-range writes, and an unknown-base no-op. `overlap`
requires a full RHS snapshot before selected stores. `invalid` requires
rejection of variable/zero width and nonintegral base on read and write.
`size_mismatch` is a runtime-negative boundary: if compilation later succeeds,
the simulator must report a runtime error and leave every element unchanged.
`control` exercises existing scalar dynamic-array access and direct
constant-colon slicing.

Against installed `ivl` SHA-256 `6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`,
both `-g2017` and `-g2023` produce the same outcomes:

| Fixture | Icarus compile | Icarus runtime | Slang 11.0.448+e222e7dc0 |
| --- | --- | --- | --- |
| `read` | RED: four unsupported dynamic-slice r-values | Not reached | Accepts, zero warnings/errors |
| `write` | RED: three indexed element part-select `sorry` diagnostics | Not reached | Accepts, zero warnings/errors |
| `overlap` | RED: one indexed element part-select `sorry` | Not reached | Accepts, zero warnings/errors |
| `size_mismatch` | RED: one indexed element part-select `sorry` | Not reached | Accepts, zero warnings/errors |
| `invalid` | Rejects with five errors; its two write sites still use the generic `sorry` | Not reached | Rejects all five invalid sites |
| `control` | Compiles with zero diagnostics | `PASS`, exit 0 | Accepts, zero warnings/errors |

Slang is an elaboration cross-check only; it does not establish runtime values.
The RED fixture hashes in `result.json` describe the original source snapshot;
the candidate fixtures add signed/wide-index and fixed-source boundaries.

The private candidate `ivl` SHA-256
`bea4a909c61157dcd8b0ba8539b5b857b549c69e0b30e1fa3154815f7a70042e`
passes the paired 2017/2023 focus 14/14 through
`tests/vvp_runtime/run_indexed_darray_slice.py`. Reads and writes check
single base evaluation, `+:`/`-:` order, X/OOB defaults, partial stores,
wide-index non-wrapping, fixed-array source direction, and whole-target or
overlapping self-assignment snapshots. A mismatched dynamic source prints a
runtime error and preserves the destination; six illegal source sites reject.
A separate legal 65,537-element width receives a clear resource-limit
diagnostic instead of exhausting compiler memory. The existing chapter-7
neighbors pass 89/89 legacy and 82/82 JSON. The focused runner is wired into
the local ivtest gate; the old negative gold now removes only the newly legal
variable-base rejection and updates its exact diagnostics.

Direct log inspection for this private candidate also confirms the full
legacy gate at 6,556/6,561 passed, zero failed, two not implemented, and three
expected failures; full JSON ran 3,548 with zero failures; negative tests
passed 155/155; and bundled VPI passed 131/131. The real-DPI UVM umbrella
loaded `/tmp/uvm_dpi_iv.vpi` and passed 358/358 with zero failures or skips,
including both VIF smokes. The complete per-run paths and hashes are in
[candidate_result.json](candidate_result.json).

[Candidate replay](candidate_result.json) uses the same private engine for
both clean pinned OTP and chip setups. All four SRAM slice errors disappear.
OTP still fails compilation with 22 other hard diagnostics, and chip with 60;
chip also aborts on an independent `entropy_src_core.sv:3324` elaboration
assertion (`base < vwid`). Neither enters DV runtime. The installed compiler
and pinned OpenTitan sources remain unchanged. This is a partial IEEE
implementation: slices wider than
65,536 elements and nonblocking/timed indexed-slice assignments still receive
explicit unsupported diagnostics.

Independent review found one false rejection in that image: a legal integral
base wider than 64 bits could not reach the existing 128-bit index carrier.
The reviewed private `ivl` SHA-256
`81f96cc9dbece51afa77c53c763526aeecec2afae8af392ee3bf936864e1a332`
accepts bases through 127 bits and keeps the offset nonwrapping. A legal
128-bit base is diagnosed as unsupported rather than invalid or silently
truncated. The eighth fixture and revised read/write cases make the paired
focus 16/16. Exact reviewed-image OTP/chip recompiles retain the old
candidate's diagnostic bodies and exit codes (OTP 24, chip abort 134), except
for the chip assertion's shifted compiler source line; all four SRAM slice
errors stay cleared and neither application reaches DV runtime. The reviewed
image passes full legacy with 6,556/6,561 ordinary passes, zero failures, two
not implemented, and three expected failures; full JSON 3,548/3,548;
negative 155/155; bundled VPI 131/131; and real-DPI UVM 358/358 with zero
failed or skipped tests and both VIF smokes passing. Exact fingerprints and
log hashes are in [reviewed_candidate_result.json](reviewed_candidate_result.json).
The new image is private; the installed image remains unchanged for live
Caliptra runs.

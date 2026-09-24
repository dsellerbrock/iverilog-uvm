# Fresh OpenTitan named smoke baseline — 2026-09-23

Scope: **2 named runtime cases** (1 xbar, 1 pwrmgr), separate from the 84-row OpenTitan census. Both use fresh images built by the current installed Icarus compiler/runtime. This is not full OpenTitan DV qualification.

| Named case | Result | Traffic and checks |
|---|---|---|
| `lowrisc:dv:top_earlgrey_xbar_peri_sim:0.1`, `xbar_base_test` / `xbar_smoke_vseq` | PASS | 180 requests; scoreboard processed 354 items and passed expected/actual and final queue checks; zero UVM warnings/errors/fatals; normal `$finish`. |
| `lowrisc:dv:pwrmgr_sim:0.1`, `pwrmgr_base_test` / `pwrmgr_smoke_vseq`, seed 1 | PASS | 25 TileLink requests and 25 responses; scoreboard received 25 A and 25 D items; zero UVM warnings/errors/fatals; normal `$finish`. |

Pinned OpenTitan source is Earlgrey-PROD-M6 at `a78922f14a8cc20c7ee569f322a04626f2ac6127` and the checkout is clean. Xbar uses no overlay. Pwrmgr uses `docs/conformance/release_overlays/opentitan/pwrmgr_clock_activity.patch` on the generated disposable source snapshot; its source list retains `+timescale+1ns/1ps`. Exact source-list hashes, commands, image hashes, and installed-tool fingerprints are in [`result.json`](result.json).

The pwrmgr compile emitted 12 warnings: `rst_n` coercions, mixed-timescale notice, and nonblocking assignments in `always_comb`. Both runtime logs contain the known `$system()`-as-task return-value warning. These did not produce UVM warning/error/fatal counts; the runner’s documented allowlist covers the `$system()` warning.

An ancillary attempt at the previous 17-name pwrmgr seed-1 sweep was halted when scope was narrowed: 14 invocations returned exit 0, the fifteenth (`pwrmgr_disable_rom_integrity_check`) was interrupted with an empty log, and the last two were not run. Those extra invocations were not scored as conformance evidence and are excluded from the requested denominator of 2.

The same two prebuilt images were later rerun under final VVP SHA-256
`e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`.
The [runtime-only replay](final-vvp-e9b7a64a/result.json) retains both checked
PASS verdicts; compilation and the pinned source snapshots were unchanged.

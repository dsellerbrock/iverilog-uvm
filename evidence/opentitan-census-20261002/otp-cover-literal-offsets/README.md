# OpenTitan OTP cover-bin literal-offset replay (2026-10-03)

**Result: PASS.** The selected `lowrisc:dv:otp_ctrl_sim:0.1` smoke completed with zero hard errors and zero semantic debt. The compiler command used `-gcommercial-unsafe`; runtime completed in 81.857 seconds, returned zero, printed `TEST PASSED CHECKS`, and reported zero UVM warnings, errors, and fatals. The compile has 20 ordinary warnings (reset-port coercion and assertion nonblocking assignments), but none of the 36 covergroup purity warnings.

The overlay replaces the 36 `ral.<register>.get_offset()` cover-bin endpoints with the matching literal values from the pinned OTP RAL `default_map.add_reg()` table. All 36 distinct register endpoints and values were matched before applying the patch; no bins were removed or reordered. This preserves the six bins for the pinned register map and avoids the nonstandard constructor-method evaluation that caused the former semantic debt. The exact mapping is in [cover-bin-offsets.tsv](cover-bin-offsets.tsv).

The disposable combined OpenTitan source copy was derived from revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`; it has no Git metadata, so the runner records its revision as unknown/dirty. The patch preimage hash matches the OTP coverage source staged by census11. The source changes only this testbench coverage file; no RTL changes.

| File | Preimage SHA-256 | Patched SHA-256 |
|---|---|---|
| `hw/ip/otp_ctrl/dv/env/otp_ctrl_env_cov.sv` | `c64064d078bd3ee4574a17a4b6bc097e74f3a63ed0e32a35988ea20e3351e560` | `cc7fa99ddb39dd388a3a29fa241b49ceca25d19de15b5d155a9fcd425f606f01` |

The final replay used a 300-second wall timeout and no memory cap, matching the earlier successful OTP run's runner configuration. A separate capped attempt was stopped before a DV verdict because macOS denied the process-footprint monitor; it is retained in [the monitor-denied record](../otp-cover-literal-offsets-monitor-denied/result.md).

The [overlay patch](../../../docs/conformance/release_overlays/opentitan/otp_ctrl_cover_bin_literal_offsets.patch), [result JSON](result.json), [matrix report](result.md), [setup log](matrix-setup.log), [compile log](matrix-compile.log), [runtime log](matrix-runtime.log), and [Icarus source list](matrix-iverilog.scr) record the selected result. The full 49-target census has not been rerun.

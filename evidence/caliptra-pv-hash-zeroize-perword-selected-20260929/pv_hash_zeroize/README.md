# `pv_hash_zeroize` selected patched-source replay — 2026-09-29

The first selected run on the merged-speedup Caliptra compiler passes with `-gcommercial-unsafe` and the named reset, checker-source, AXI RUSER, SHA-512 per-word checker/observer, and ephemeral JTAG-port copied-source overlays. Pinned released source hashes and image fingerprints match the runner's manifest. This is outside the historical selected-52 aggregate.

`result.json` records VVP exit 0, one pass marker, zero bad diagnostics, zero timeout or 8-GiB memory-cap hits, 1,571,341,824 bytes peak physical footprint, 61,838 cycles, 20,062 retired instructions, and 20,063 trace commits. The old assertion occurred at 597,595 ns; this replay crossed that point and finished normally. `observer_window.log` preserves the 32 changed SHA block words across 597,595–598,535 ns: every change had `we=1` and `now=next`. The separate paired strict 2017/2023 and Verilator controls establish that an unwritten-word mutation still fails.

The raw VVP log and firmware artifacts remain untracked in this generated output directory; the compact result and observer extract are committed for review. The saved selected-52 count remains 20 pass / 16 four-hour timeout / 3 assertion failure / 2 low-swap kill / 11 unfinalized.

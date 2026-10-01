# HMAC status CSR mismatch: live-counter prediction overlay (2026-09-29)

**Ticket:** OT-HMAC-STATUS-MIRROR-MISMATCH. This is a selected nonstandard replay. The frozen OpenTitan 49-target result stays at **23 PASS / 49**; this replay does not change that count.

## Failure

The frozen `lowrisc:dv:hmac_sim:0.1` compiles with zero hard or semantic debt. `hmac_smoke_vseq` then fails at 7,973,565 ps: the status read returns `0x2`, but the scoreboard mirror expects `0x10`.

## Cause

The pinned `hw/ip/hmac/dv/env/hmac_scoreboard.sv` refreshes `hmac_fifo_depth` one clock after a counter change (`cfg.clk_rst_vif.wait_clks(1)`). It builds the status prediction from that cached depth.
- **At the failing read:** both counters were 9, so the live depth was 0 and the FIFO empty. That is exactly the DUT's `0x2`.
- **The mismatch:** `0x10` is the stale depth of 1.
- **Why it's a race:** the cache refresh and the prediction are waiters on clocking events that trigger in the same Observed region (IEEE 1800-2017 14.13). They resume in unspecified order (4.5, 4.7), so either prediction is conformant.

The reducer `docs/conformance/repros/hmac_status_snapshot/status_event_order.sv` shows the cached form racing and the live form order-free. It prints `cached prediction 0x10 (legal: 0x2 or 0x10), live prediction 0x2` and `PASS` under both `-g2017` and `-g2023`, and slang accepts it.

## Overlay

`docs/conformance/release_overlays/opentitan/hmac_status_live_counters.patch` (SHA-256 `2a4e8d33e3c2dca2507ff37fcf976fa083b93935cc19ab381194f85bc72fe22d`) computes the status prediction from the live `hmac_wr_cnt - hmac_rd_cnt`.
- The status comparison, its `UVM_PREDICT_READ`, and every transaction check are unchanged.
- It applies with zero fuzz to the pinned scoreboard, turning SHA-256 `57bee6f1636dfbad…` into `8e42aee7393eb0e2…`.
- It is applied only to the disposable copy `/private/tmp/ot-hmac-live-counters-selected-20260929/source`. The pinned corpus `a78922f14a8cc20c7ee569f322a04626f2ac6127` is clean.

## Selected replay (current image)

**Compiler:** `lib/ivl/ivl` SHA-256 `0d50ec5d7b92ad405fdf44b36aacd9723dec1795a34c4d561d2aa249b5e09d62`, `bin/vvp` `5b9ed7a8ed8006a998b55c0bc42d035aa99ddeb9c1b3495fd0b4651cf23600c3`. This image includes the interpreter and regression-runner speedups merged in `8e57f8364`.

**Command:** `selected-rerun-command.sh`, run with pinned Python 3.13.15 and `PYTHONHASHSEED=2`:

```
--lane runtime --core lowrisc:dv:hmac_sim:0.1 --commercial-unsafe --jobs 1 --runtime-timeout 300 --runtime-memory-mib 4096
```

**Result:** **PASS** (`selected-rerun-result.json`, `selected-rerun-runtime.log`).
- Setup and compile: compile exit 0, 0 hard errors, 0 semantic debt.
- Runtime: exit 0 in 191.8 s; 22 sequences started; one checked `TEST PASSED CHECKS`; UVM_WARNING/ERROR/FATAL 0; runtime debt 0.
- Memory: peak physical footprint 482,592,208 bytes, under the 4 GiB cap with no monitor error.

A second, independent selected replay with the identical configuration also passed (`selected-result.json`, `selected-*.log`). Another agent ran it into the same work-directory name and it finished first: 201.2 s, 22 sequences, one checked banner, zero errors and debt, 483,263,976-byte peak, and the same eight setup warnings. An earlier focused copied-source run also passed: 22/22 sequences, 189.8 s, 514 MB peak (`focused-runtime.json`).

The first matrix attempt was interrupted in VVP at the user's request. It has **0/1 results and no verdict**, and its partial report remains only at `/private/tmp/ot-hmac-live-counters-selected-20260929/selected-result.json`.

## Setup warnings

FuseSoC reports eight `WARNING: ... has unknown file type 'cSource'` lines for `lowrisc:dv:cryptoc_dpi`: `util.c`, `sha.c`, `sha256.c`, `sha384.c`, `sha512.c`, `hmac.c`, `hmac_wrap.c` and `cryptoc_dpi.c`.

They are Edalize packaging notices. The matrix's native DPI step compiled all eight, plus the DPI export stubs, into `matrix-dpi.so` (`selected-rerun-dpi-build.log`).
- `dpi_skipped_sources` is empty.
- The library loaded at runtime.
- The passing scoreboard exercised its digest model.

**Classification:** benign setup diagnostics with no semantic effect. They are recorded, not allowlisted; the ticket forbids warning allowlists.

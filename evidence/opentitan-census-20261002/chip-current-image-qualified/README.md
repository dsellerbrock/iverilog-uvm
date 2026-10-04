# OpenTitan Chip selected current-image replay (2026-10-03)

**Result: PASS.** `lowrisc:dv:chip_sim:0.1` ran the pinned `xbar_smoke` (`xbar_base_test` / `xbar_smoke_vseq`) on the current Icarus image. The exact compile command includes `-gcommercial-unsafe`. Runtime completed in 453.108 seconds under a 4 GiB footprint cap; peak footprint was 2,953,251,384 bytes. Compile and runtime error/debt counts are zero, the checked `TEST PASSED CHECKS` marker is present, setup has zero actionable warnings, and no native DPI source was skipped.

The disposable source copy started from census11's pinned OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, inheriting the earlier Trial1, SPI Device, Entropy Source, and I2C overlays. The Chip cleanup patch [chip_tracer_lifetime_randomize_check.patch](../../../docs/conformance/release_overlays/opentitan/chip_tracer_lifetime_randomize_check.patch) was then applied. Its four changes:

- Make the `ibex_tracer` block-local file-handle and filename variables automatic.
- Check both DFT strap randomization return values and fail with `uvm_fatal` on failure.
- Explicitly discard UARTDPI's unused `$value$plusargs()` success bit.
- Mark the helper-only Python fileset as FuseSoC `user` data, removing its two unknown-type warnings.

The source preimages and patched SHA-256 values are:

| Source | Before | After |
|---|---|---|
| `hw/vendor/lowrisc_ibex/rtl/ibex_tracer.sv` | `74326975d4fc618c97d95cf5451dd830ed5c79798c87d141858fcaf479120e29` | `6c765a9999c238d7ae12d4a5e211b5cdfe74ef1a729414555b3a6ff8e54e48c5` |
| `hw/top_earlgrey/dv/env/seq_lib/chip_tap_straps_vseq.sv` | `6858a28a53b38daa245b330bf7e9e096a5f27df0356bc41a26d70c2b362cdb87` | `deb2aa57c5704897b0fd94e721305f9a50181070935a1c5fca20f52eea4e0f4a` |
| `hw/dv/dpi/uartdpi/uartdpi.sv` | `fe1c2cae5e57884e6918cd45056d587c1792defcea2f99a953d19def087cb338` | `bc2a6d88a7380afb003af78c30b62e199b8b07c567921cb2938df88367752716` |
| `check_tool_requirements.core` | `fc321529e33c80fe95aa44db4c8eb56b9177267c1cb1f5bffe5e6d1f6f80cac3` | `b0a7dc491db3322bf2d9e861263e53725cb2f560057352082a38c1a090aa91b0` |

FuseSoC's remaining 22 native `cSource`/`cppSource` notices are retained in the setup log and marked benign only after every listed native source was compiled and linked. The compiler's mixed-timescale notice is also retained; this simulation explicitly declares the `1ns/1ps` default. The selected runner included `--native-pkg-config openssl --native-pkg-config libelf` so the complete DPI source closure built.

The [result JSON](result.json), [matrix report](result.md), [setup log](matrix-setup.log), [compile log](matrix-compile.log), [runtime log](matrix-runtime.log), [source list](matrix-iverilog.scr), and [native DPI build log](matrix-dpi-build.log) are saved beside this record. The full 49-target census has not been rerun.

# OpenTitan SPI TPM selected current-image replay (2026-10-03)

**Result: PASS.** The selected `lowrisc:dv:spi_tpm_sim:0.1` `spi_tpm_smoke` completed with zero hard errors and zero semantic debt. The compile command contains `-gcommercial-unsafe`; the run used a 4 GiB memory guard, returned zero, and printed the checked `TEST PASSED CHECKS` marker. Runtime was 1.022 seconds and ended at 22.492933 us simulated time.

The disposable source was based on pinned OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`. This selected replay used the combined current-image copy, which also contains previously validated overlays for other rows. The TPM overlay itself is standalone against the pinned testbench and changes no RTL.

The [overlay patch](../../../docs/conformance/release_overlays/opentitan/spi_tpm_current_interface_sram_runtime.patch) makes the pre-DV testbench match the released `spi_tpm` interface. It maps the three TPM reset/event inputs to active-low CSB, provides a 1024-word by 32-bit SRAM model with a one-cycle SPI-domain read response and byte-masked writes, and lets the software model read write-FIFO bytes from SRAM. It packs software read-FIFO data into 32-bit words and releases the write FIFO after checking each byte. The host monitor now advances one sampling edge between consecutive returned bytes.

The test checks:

- Software-serviced FIFO read returns `a0 a1`.
- Hardware access-register read returns `15 ff ff ff`.
- Unsupported locality returns `ff ff`.
- Software reads the 4-byte `ef be ad de` payload back from SRAM.
- Software reads back and checks all 64 bytes of the maximum-size payload.

The patch preimage and selected-source SHA-256 values are:

| File | Pinned preimage | Patched source |
|---|---|---|
| `hw/ip/spi_device/pre_dv/tb/spi_tpm_tb.sv` | `8cf326b4bba4e538fe3b61fe03a4d540436bbb70cc8046bfb5c8a1db2fc9c254` | `686ca53275ccca4aa4ccc96a71429be97a03de18f6434c47db2035340edb57ba` |

The saved [result JSON](result.json), [matrix report](result.md), [setup log](matrix-setup.log), [compile log](matrix-compile.log), [runtime log](matrix-runtime.log), and [Icarus source list](matrix-iverilog.scr) record the selected command and output. The compile log confirms `-gcommercial-unsafe` and has no warnings. The full 49-target census has not been rerun.

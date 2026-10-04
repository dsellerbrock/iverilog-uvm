# SPI Device current-image runtime

`lowrisc:dv:spi_device_sim:0.1` passes on the current Icarus image with zero hard compile errors, semantic debt, runtime errors, or runtime debt. The compile command includes `-gcommercial-unsafe`. Runtime completed in 584.43 seconds; the 4 GiB physical-footprint guard recorded 553,026,376 bytes.

The disposable OpenTitan root was copied from the Trial1 current-image copy, based on census11 revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, with `.git` excluded. It contains the Trial1 core-layout overlay and [SPI Device coverpoint patch](../../../docs/conformance/release_overlays/opentitan/spi_device_num_lanes_coverpoint.patch). The SPI source preimage hash is `3416c5808ea575bff22a15aac2f034434ee25dbaa112aabeef5cdc01489919b4`; the patched hash is `710343c086e2a0ef21d4d2493ab4e9cdc42db4ffdf56374dd81f19f3836b8410`. The pinned source was left unchanged.

The [result JSON](result.json) records fingerprints, exact commands, and status. The [setup](matrix-setup.log), [compile](matrix-compile.log), [runtime](matrix-runtime.log), and [compiler source list](matrix-iverilog.scr) are preserved beside it. This selected-row replay updates mixed current-image evidence; it is not a fresh 49-row census.

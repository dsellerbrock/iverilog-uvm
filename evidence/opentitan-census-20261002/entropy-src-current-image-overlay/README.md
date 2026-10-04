# Entropy Source current-image replay

`lowrisc:dv:entropy_src_sim:0.1` passes on the current Icarus image with zero hard compile errors, semantic debt, runtime errors, or runtime debt. The compile command includes `-gcommercial-unsafe`. Runtime completed in 29.644 seconds; the 4 GiB physical-footprint guard recorded 386,187,912 bytes.

The source overlay changes `sigma_to_int` from an implicit one-bit `unsigned` return type to `int unsigned`, matching the 32-bit threshold bins. It was applied to a disposable copy after the existing [Entropy coverage-range patch](../../../docs/conformance/release_overlays/opentitan/entropy_src_coverage_ranges.patch). This copy also carries the Trial1 and SPI Device overlays. The Entropy source preimage hash is `8711cc3b3d5262dd611f9dfcf06db88a739afd2982e528c86c1aedc9979c75e0`; the patched hash is `5f551c6ed1acb64f2bcd71c809409bde4f3a580f642ef346a30af5fbcf69b8b2`. The pinned source was left unchanged.

The [result JSON](result.json) records fingerprints, exact commands, and status. The [setup](matrix-setup.log), [compile](matrix-compile.log), [runtime](matrix-runtime.log), and [compiler source list](matrix-iverilog.scr) are preserved beside it. The matrix self-test verifies that zero scoreboard drop counters are benign while a positive count remains debt. This selected-row replay is not a fresh 49-row census.

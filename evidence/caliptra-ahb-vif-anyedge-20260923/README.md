# Caliptra interface-port forwarding at time zero

The first nonstandard Icarus L0 `smoke_test_veer` runtime in
`../caliptra-icarus-l0-unsafe-first-loaderfix-20260923/` loaded its image but
stopped before firmware execution with `%wait/vif/anyedge` on a null handle.
The diagnostic VVP copy inserted a trace before each of the 326 anyedge waits;
unbuffered output identifies **T_34319** as the first invalid wait. Its
`s_axi_if` handle is the `axi_sub_rd` port bound at
`caliptra-rtl/src/axi/rtl/axi_sub.sv:150`, and member 27 is `rready` of the
physical `tb_axi_complex_i.axi_fifo_if`. The relevant wait is synthesized
from an interface-member read in `axi_sub_rd.sv`; the pinned sources were not
edited. The trace log is retained as `full-top-trace-unbuffered.log`; the
temporary 309 MiB traced VVP image was removed after localization.

The generated VVP initializer **T_34409** copies the parent
`axi_sub.s_axi_r_if` to child `axi_sub_rd.s_axi_if` before parent initializer
**T_34417** copies its own source. The pre-simulation initializer queue runs
in emitted order. The existing elaboration comment at `elaborate.cc:5973`
explicitly handles one forwarding level and notes that deeper chains fail.
By contrast, all 17 AHB responder array slots have direct `%new/vif` stores,
and the 17-element control in `array17_safe.sv` passes in 2017 and 2023 modes.

`forward_chain_red.sv` reproduces the three-level forwarding failure in both
editions; `baseline-red-runtime.json` records exit 1 and the exact diagnostic
from images compiled before the fix. The Icarus patch orders only generated
interface-port binding initializers parent before child in both target paths.
`focused-result.json` records eight direct checks on the installed candidate:
the three-level chain, direct binding, and one-hop binding pass with correct
values in both editions; a genuine null virtual interface still exits 1 with
the same diagnostic. The matched repository regressions are named
`sv_interface_port_forward_{chain,direct,onehop,null}` and their 2023 peers.

This is an Icarus interface-port initialization fix. It does not change the
separate `-gcommercial-unsafe` waiver, and these focused checks are not a
Caliptra L0 pass.

The installed target's `target_query("stream_processes")` and
`target_query("order_processes")` both return `"true"` unconditionally.
`iverilog -v -g2017 -Iivtest -s sv_interface_port_forward_chain ...` printed
`invoking incremental target design begin` and its image ran `PASSED`.
No documented option in this checkout selects the legacy complete-target
callback with the installed binary, so the legacy ordering implementation is
source-reviewed but not directly exercised by these focused runs.

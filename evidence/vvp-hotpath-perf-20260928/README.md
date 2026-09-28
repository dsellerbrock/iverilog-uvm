# VVP hot-path performance evidence (2026-09-28)

This directory backs
[the assessment log](../../docs/conformance/session_logs/2026-09-28_vvp_single_core_multicore_assessment.md).

- `tb_a2b.sv`: the disposable A2B reducer testbench. Compile it with
  `-DCYC=<n>` against the unmodified Adams Bridge
  `b77e3d899e828d626cfc2a0d26a6b5704cc121e0` sources
  `abr_masked_A2B_conv.sv`, `abr_masked_full_adder.sv` and
  `abr_masked_AND.sv`.
- `unroll_a2b.py`: writes the manually unrolled **diagnostic** copy. It is
  not an RTL workaround.
- `results.json`: the paired instruction counts, CPU times and image sizes.
- `vpi_auto_index_probe.{c,sv}`: shows that value-change callbacks are
  refused on the automatic for-init index and fire per store on a static
  index.
- `unpacked_slice_output_port.sv`, `two_state_oob_part_select.sv` and
  `discovered_debt_repro.log`: reproduce DD-064 and DD-065.

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

## Common-workload survey (2026-09-29)

- `workloads/`: testbenches and scripts.
  - `tb_sha.sv` drives the Caliptra v2.1.2 secworks SHA cores.
  - `tb_pico.v` is picorv32 `testbench_ez` with a checksum;
    `tb_pico_dump.v` adds `$dumpvars`.
  - `uvm_alu*.sv` are the UVM environments with different constraint
    sets.
  - `fst_ctl.v` exercises every dump control task.
  - `build.sh` and `timeit.sh` build the baseline and new images and
    time them in interleaved pairs.
- `timing_round1.log` and `timing_round2.log`: raw paired CPU times.
  Round 2 is after the flat symbol-table fix.

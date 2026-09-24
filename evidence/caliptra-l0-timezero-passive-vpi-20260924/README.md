# Caliptra startup assertion trace (passive, 2026-09-24)

This is a six-nanosecond diagnostic of the **existing** exact unsafe-VIF
Caliptra first-case compiled image. It is not an L0 result. The VPI plugin
only reads values and stops this disposable replay at 6 ns; it does not force
signals, change assertions, or alter the pinned sources or compiled image.
`trace.filtered.log` contains selected lines, with trailing spaces removed,
prefixed by their line numbers in the full temporary run log. No full
runtime/VCD or key-vector output is retained here.
The source checkouts were Caliptra v2.1.2
`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e` and Adams Bridge v2.0.3
`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`.

Image:
`evidence/caliptra-icarus-l0-unsafe-vif-first-20260924/caliptra_top_tb.vvp`
(SHA-256 `ba7d82ece86deb720850feba64dfa71181c21fc7b72f53bea9db55a0e71942d0`).
Probe source: `startup_probe.c` (SHA-256
`a6c6614ef1627d2384d19d48af4c6c4975aeb6c33bd0d133557c52e75b52f787`).
The temporary compiled VPI plugin SHA-256 was
`7a185f894e3f57e4ff277b43bf59c6dde5b7d52b69d445dba847fcc2ee35ac75`.
Runtime files were copied from the first-case `smoke_test_veer` directory to
`/tmp/caliptra-startup-vpi-20260924/smoke_test_veer`; logs/results were
excluded. The installed Icarus `iverilog-vpi` built the probe. From that
temporary working directory the diagnostic command was:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/local-install/bin/iverilog-vpi \
  -o startup_probe.vpi startup_probe.c
```

The build ran in `/tmp/caliptra-startup-vpi-20260924`, after copying the
`startup_probe.c` retained here. The probe produced harmless C warnings about
implicit zero-initialization of its remaining struct fields. It exited zero.
The replay, run from its copied `smoke_test_veer` directory, used:

```sh
/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/local-install/bin/vvp \
  -M /tmp/caliptra-startup-vpi-20260924 -m startup_probe \
  -d /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-jtagdpi-native-20260923/jtagdpi.vpi \
  -n /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/evidence/caliptra-icarus-l0-unsafe-vif-first-20260924/caliptra_top_tb.vvp \
  +CLP_REGRESSION +CLP_BUS_LOGS
```

The original run's 19 startup failure actions divide into 14 Veer module-item
`assert #0` failures at time zero, two Adams Bridge immediate assertion errors
at the first 5 ns clock, and three DOE cold-reset SVA failures at 5 ns.
The following are the released source sites and observed state:

| Actions | Released checker | Observation before first clock |
| ---: | --- | --- |
| 1 | `el2_veer.sv:970`, fetch during debug halt | Fetch request, halt, and single-step inputs are `x`. |
| 5 | `el2_dma_ctrl.sv:505`, FIFO done implies valid | All five done/valid bits are `x`. |
| 4 | `el2_lsu_bus_buffer.sv:958`, empty buffer age | `lsu_bus_buffer_empty_any` is `x`; age is not separately probed. |
| 1 | `el2_lsu_stbuf.sv:344`, valid count | Four valid bits are `x`. |
| 1 | `el2_dec_gpr_ctl.sv:94`, write collision | Collision predicate is `x`. |
| 2 | `el2_dec_tlu_ctl.sv:1250-51`, fast-interrupt flush and halted commit | All sampled predicate inputs are `x`. |
| 2 | `abr_reg.sv:68,70`, write/read acknowledgment requires request | Adams Bridge `rst_b`, request, pending and both acknowledgments are `x`. |
| 3 | `caliptra_top_sva.sv:138-181`, DOE lock on hard reset | `hard_rst_b=0`, while all three lock flops are `x`. |

At 1 ps and 4.999 ns, the testbench's `cptra_pwrgood=0` and `cptra_rst_b=0`,
yet Veer `core_rst_l=x`, Adams Bridge `rst_b=x`, and the state listed above is
still unknown. At the first `core_clk` rising edge (5 ns), the ABR checks run
with unknown reset/ack state. In that same time slot the reset and acks become
zero; the three DOE lock flops also become zero, after their first-edge SVA
samples have reported failure. By 5.001 ns, reset, acks, Veer state, and DOE
locks are resolved to their reset values. The source's Veer `assert #0` checks
are unguarded at time zero. Thus the diagnostics are real assertion actions on
unknown startup values, not evidence of actual DMA, fetch, write collision,
request/ack, or DOE lock activity. This trace alone does not establish whether
the cause is Icarus scheduling or the released testbench's initial reset
ordering. A separate hash-guarded testbench-only `#0` reset-drive diagnostic
can distinguish that, while leaving every checker intact.

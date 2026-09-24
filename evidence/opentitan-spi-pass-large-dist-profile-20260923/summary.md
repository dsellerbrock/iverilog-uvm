# Bounded SPI flash-mode solver sample

Replay used the saved `/tmp/ivl-focus-20260923/spi-07d8ba6.vvp` from the current candidate, with the six metadata plusargs from the pinned SPI runtime record:

```text
/tmp/ivl-focus-20260923/spi-07d8ba6.vvp +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_LOW +cdc_instrumentation_enabled=1 +smoke_test=1 +UVM_TESTNAME=spi_device_base_test +UVM_TEST_SEQ=spi_device_flash_mode_vseq
```

The process ran from the generated `sim-icarus` runtime directory. After one second, `/usr/bin/sample <pid> 3 -file sample.txt` sampled it for three seconds; it was then stopped. The captured output contains only the pre-existing `$system`-as-task warning and UVM test startup, so this is not a completion result.

The sample call graph enters `vvp_z3_randomize_scope`, `z3_resolve_dist_exact`, and repeated `Z3_solver_check_assumptions` calls. This confirms the active work is solver-side exact projection rather than VVP loading. The process footprint was 844.5 MB when sampled (2.8 GB peak reported by `sample`).

`sample.txt` is the raw macOS sample output and `replay.log` is the bounded replay log. After sampling, SIGINT requested VVP's normal stop; it remained in output flushing for the one-second grace period and was then SIGKILL-stopped. No build, install, or shared test runner was used.

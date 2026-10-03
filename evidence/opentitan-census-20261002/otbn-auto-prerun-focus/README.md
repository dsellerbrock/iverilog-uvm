# OTBN smoke with automatic ELF generation and trace finalization

The selected `lowrisc:dv:otbn_sim:0.1` / `otbn_smoke` run verifies the runner path in `scripts/opentitan_matrix.py`. It is one target only; it does not refresh census11's 49-row totals.

The runner invokes OpenTitan's pinned `hw/ip/otbn/dv/uvm/gen-binaries.py` with the smoke source directory and generates `smoke_test.elf` before simulation. Its SHA-256 is `e47c6d70669a8b2837e8476b6e3ca1eeaadb98b62bab87321a0ce698348cb827`. The run used xPack RV32 tools through `RV32_TOOL_AS` and `RV32_TOOL_LD`, `REPO_TOP` pointing to the pinned OpenTitan checkout, native `libelf`, and `-gcommercial-unsafe` for the UVM compile.

FuseSoC's staged `otbn_model.cc` is copied and changed only when the pinned source hash matches `751102f30ec5f8c28cd05aff653f4ff4baf641bc6fba286faae99697424bfb4e`. The runner calls `OtbnTraceChecker::Finish()` at final model destruction, where all RTL/ISS trace pairs can be checked. It does not change the pinned source checkout or run the full register comparison that failed when attempted immediately at ISS completion. The staged overlay hash is `edaa22262c3b45555384325a09b70a9874f456b732f2b979fb3b8ef169ad8915`.

The runtime returned 0 after 102.1 seconds and printed `TEST PASSED CHECKS`. The matrix verdict is **PASS**: zero hard errors, semantic debt, actionable setup warnings, runtime errors, or runtime debt. FuseSoC's native-file-type notices are verified as benign because all staged native sources, including the patched OTBN model, were compiled into and loaded from the DPI library. See [result.json](result.json), [result.md](result.md), [matrix-pre-run.log](matrix-pre-run.log), [matrix-compile.log](matrix-compile.log), [matrix-dpi-build.log](matrix-dpi-build.log), and [matrix-runtime.log](matrix-runtime.log).

The earlier selected run without trace finalization remains in [result-before-trace-finalize.json](result-before-trace-finalize.json) and [runtime-before-trace-finalize.log](runtime-before-trace-finalize.log); it printed the pass banner but had the shutdown warning. The 49-target census has not yet been rerun.

The root-cause probe is in [trace-lifecycle-debug.log](trace-lifecycle-debug.log): no `Finish()` call occurred, and both pending queues were empty at destruction. The rejected immediate full-check experiment is recorded in [rejected-hypothesis.json](rejected-hypothesis.json) and [premature-model-check-rejected.log](premature-model-check-rejected.log); it produced real RTL/ISS register mismatches and is not part of the runner.

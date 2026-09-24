# Caliptra first L0 case after the PIC partial-driver fix

The pinned `smoke_test_veer` case used the exact released test selection,
firmware and native vectors, the non-`VERILATOR` testbench, original assertions,
and explicit `-gcommercial-unsafe`. The diagnostic filelist excludes only the
unused invalid AXI4PC proprietary-checker placeholder. The [command](compile.command.json),
[summary](summary.json), [case result](smoke_test_veer/result.json), and
[compiler output](compile.log) record this local run; the large simulator and
instruction logs remain local and are reproducible with the L0 runner.

The PIC fix let the runtime advance beyond the earlier 43.865 us terminal
SOC IFC fatal: firmware retired 633 instructions across 4,348 cycles, the
simulator exited 0, and the testbench printed one `TESTCASE PASSED` marker.
The run still has **17,863 assertion/error diagnostics** (including time-zero
Veer/Adams Bridge errors and the KV/MLDSA checker-function messages), so its
qualifying result is **0/1**. It is a nonstandard compatibility result, not an
IEEE-conforming L0 pass. The other 51 selected cases were not run. The pinned
source checkouts and tool/vector fingerprints stayed unchanged during the run.

Two unsuppressed VVP target `sorry` messages at the pinned testbench's
procedural `force` assignments say their RHS is evaluated once when each
assignment executes. Their practical effect on this case is not established.

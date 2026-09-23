# DOE reset-window SVA differential (2026-09-23)

The pinned Caliptra v2.1.2 `smoke_test_doe_scan` failure includes a pending
`clear |=> status` attempt when reset is asserted and deasserted while the
assertion clock is gated. The captured DUT status is zero at the first clock
after reset. This standalone reducer preserves that timing: an antecedent
at 5 ns, a complete reset pulse at 11–12 ns, and a false consequent at 15 ns.

IEEE 1800 `disable iff (!rst_b)` aborts the pending attempt on the reset
pulse even though neither clock edge samples reset low. The control property
without `disable iff` must fail once. `disable_midwindow.sv` checks both, so
an implementation cannot pass by ignoring the antecedent or turning off all
assertions.

| Simulator | Control failures | Disabled-property failures | Exit |
| --- | ---: | ---: | ---: |
| Icarus local campaign build, `-g2017 -gassertions` | 1 | 0 | 0 |
| Installed Verilator 5.050 | 1 | 1 | 1 |
| Isolated Verilator v5.052 tag source | 1 | 1 | 1 |

The v5.052 source came from the official tag archive (`8c8d2e11e6ad32f641dd250742a94195ddecb912e2e2dabe2f42ddbbb99c1092`). The isolated Mac build used a matching Flex C++ header and a local Flex signature compatibility change in the extracted build tree; the SVA implementation and reducer were unchanged. The archive build reports `rev vUNKNOWN` because it lacks Git metadata. No system toolchain or pinned application checkout was modified.

This confirms a Verilator reset-window behavior mismatch in the small case.
A fresh pinned Caliptra v2.1.2 DOE scan replay with isolated v5.052, the
selected KV diagnostic overlay, and official xPack GCC 15.2 RV32IMC/ILP32
also still emits exactly one `SVA ERROR: DOE STATUS valid bit not set after
clear obf secrets cmd`. Its build exits zero and prints `* TESTCASE PASSED`,
but that display-based SVA failure makes the actual result **fail**. The DOE
assertion and action were unchanged and no probe instrumentation was present.
The standalone mismatch matches the application's reset-window trace; this
is strong evidence of a simulator issue, but it does not prove it is the only
DOE issue or qualify the Caliptra test. Do not count the pass banner as a pass.

The focused replay is recorded in `doe_scan_v5052.result.json`, with the
exact invocation in `doe_scan_v5052.command.json` and the simulator log in
`doe_scan_v5052.sim.log.gz`. The source assertion hash is
`7e832e09d1b95785db47226cc3dfaf1064771c14e413e354e7f66fd69938cac6`.

Reproduce the reducer with `verilator --binary --timing --assert --top-module tb
--Mdir <output> -CFLAGS '-std=gnu++20' disable_midwindow.sv`, then execute
`<output>/Vtb`. For Icarus, compile with `iverilog -g2017 -gassertions -s tb`
and run with `vvp`. The raw outputs are preserved in `results.json` and the
full build logs in the sibling workspace evidence directory
`evidence/verilator-midwindow-doe-20260923`.

# [IEEE 1800] §10.6.1/§10.6.2 — selected class-property assign/force aborts; whole force asserts

**Status:** Draft for the supervisor to file. This agent has not opened an issue.

**Related:** active issue #769 and PR #1121. This is the class-property l-value path, which the non-class guard in #1121 does not cover.

## Expected behavior

IEEE 1800-2023 §10.6.1 states that the assign LHS is a singular variable reference or concatenation and “shall not be a bit-select or a part-select of a variable.” Section 10.6.2 gives the same restriction for force/release targets. A selected class property therefore needs a compile-time error. A whole class-property reference is a singular variable reference; force must be implemented or rejected cleanly, never abort the compiler.

## Reproduction

Environment: MacBook-Air.local; Icarus 13.0-devel, local install built from commit `f31c698305941900a5eb347fdeaae35d0b0e2cf6`; all probes were run through `~/codex-supervisor/localrun`. Source files, exact scripts, outputs and hashes are in `evidence/m9-issue769-class-probe-20261024/`.

1. **Selected force:** `class C; int p; bit [7:0] q; endclass; module t; C c; initial begin c=new; c.q=0; force c.q[0]=1'b1; #1 $display("q=%02h",c.q); $finish; end endmodule`. For each edition, run `local-install/bin/iverilog -g<edition> -o select-<edition>.vvp class_select.sv`, then `local-install/bin/vvp select-<edition>.vvp`. Under `-g2017` and `-g2023`, compile returns 0; VVP returns 134 with `Assertion failed: (net->fil), function of_FORCE_VEC4_OFF, file vthread.cc, line 19681.`

2. **Selected assign/deassign:** same declarations; `assign c.q[0] = 1'b1; #1 $display("q=%02h",c.q); deassign c.q[0];`. Under both editions, compile returns 0; VVP returns 134 with `Assertion failed: (sig), function of_CASSIGN_VEC4_OFF, file vthread.cc, line 15757.`

3. **Whole-property force:** `class C; int p; bit [7:0] q; endclass; module t; C c; initial begin c=new; c.p=0; force c.p=1; #1 $display("p=%0d",c.p); $finish; end endmodule`. Under both editions, Icarus returns 134 during VVP target generation with `Assertion failed: (ivl_lval_width(lval) == ivl_signal_width(lsig)), function force_vector_to_lval, file vvp_process.c, line 2545.`

Probe commit: `f31c698305941900a5eb347fdeaae35d0b0e2cf6`. The exact `.sv` inputs, commands and captured outputs are attached in the evidence directory.

**Classification:** selected-target IEEE conformance gap plus runtime/compiler robustness defects. The three paths fail at different points; the first two compile with rc=0 but are not successful behavior because VVP aborts.

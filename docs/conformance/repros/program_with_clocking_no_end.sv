// M8 audit finding (2026-07): a PROGRAM whose only remaining activity after
// its initial procedures complete is a clocking block does not end the
// simulation — it hangs.
//
// Expected (IEEE 1800-2017 24.7): when all program initial procedures
// terminate, $finish is implicitly called and the simulation ends.
//
// Observed: the program's initial completes (prints "PROG done"), but the
// simulation runs forever.
//
// Root cause: the synthesized clocking sampler is lowered as an IVL_PR_INITIAL
// wrapping a NetForever loop (elaborate.cc, elaborate_clocking_samplers_), so
// in a program scope tgt-vvp tags it `.thread $prog` alongside the real user
// initial. The M6B program-completion counter therefore never reaches zero
// (the sampler never completes) and end-of-simulation never fires.
//
// A targeted fix (excluding the sampler/apply processes from the $prog count
// via an `_ivl_clocking_bg` attribute) makes this case end correctly, BUT it
// regresses tests/g01_module_clocking_test: that test relies on the sampler
// keeping a sub-program alive so a MODULE initial can run its checks and call
// $finish AFTER the program's initial completes. With the fix the program's
// completion ends the simulation first, cutting off the module's checks.
//
// Resolving this cleanly requires deciding the IEEE 24.7 semantics for a mixed
// program+module testbench (does a program's completion preempt a module still
// mid-test?) and updating g01 accordingly. Deferred as an M6B/M8 item rather
// than shipped with the g01 regression. See session log 2026-07.

program p(input bit clk, input logic [7:0] d);
  clocking cb @(posedge clk); input d; endclocking
  initial begin
    @(cb);
    $display("PROG done @%0t cb.d=%0h", $time, cb.d);
    // Program completes here -> IEEE 24.7 says the simulation should end.
  end
endprogram

module top;
  bit clk = 0;
  always #5 clk = ~clk;
  logic [7:0] d = 8'h42;
  p pp(clk, d);
  // No module $finish and no watchdog: if program-completion worked, the sim
  // would end here. Today it hangs.
endmodule

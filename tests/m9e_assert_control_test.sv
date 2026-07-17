// M9E: assertion control system tasks (IEEE 1800-2017 20.12).
// $assertoff stops reporting concurrent-assertion failures, $asserton
// resumes, $assertkill also stops. A single global enable flag gates the
// synthesized checkers' failure actions. (The optional [levels, list]
// scope arguments are accepted but treated globally.)
//
// Test: a |-> b with b held low fails every cycle. We verify failures
// accrue while ON, freeze while OFF, resume after $asserton, and freeze
// again after $assertkill.
module m9e_assert_control_test_top;
  logic clk = 0, a = 1, b = 0;
  int fails = 0;
  int f1, f2, f3, f4;
  int errors = 0;
  always #5 clk = ~clk;

  ap: assert property (@(posedge clk) a |-> b) else fails++;

  task run3; begin
    repeat (3) begin @(posedge clk); #1; end
  end endtask

  initial begin
    a = 1; b = 0;
    run3;          f1 = fails;   // ON: failures accrue
    $assertoff;
    run3;          f2 = fails;   // OFF: frozen
    $asserton;
    run3;          f3 = fails;   // ON: resume
    $assertkill;
    run3;          f4 = fails;   // killed: frozen

    if (f1 == 0)  begin $display("FAIL: ON phase produced no failures"); errors++; end
    if (f2 != f1) begin $display("FAIL: $assertoff did not freeze (%0d->%0d)", f1, f2); errors++; end
    if (f3 <= f2) begin $display("FAIL: $asserton did not resume (%0d->%0d)", f2, f3); errors++; end
    if (f4 != f3) begin $display("FAIL: $assertkill did not freeze (%0d->%0d)", f3, f4); errors++; end

    if (errors == 0) $display("PASS: m9e assertion control");
    else $display("FAIL: m9e assertion control (%0d errors)", errors);
    $finish(0);
  end
endmodule

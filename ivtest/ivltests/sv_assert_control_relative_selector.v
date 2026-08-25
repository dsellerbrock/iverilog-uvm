// Assertion-control names are resolved in their lexical call context.  This
// includes a bare assertion label reached from a nested procedural block and
// a relative child path.  Duplicate labels in separate interface instances
// must retain distinct identities.
interface adc_ctrl_sva_if #(bit CONTROL = 0) (input logic clk);
  integer wakeup_failures = 0;

  // Keep this controller before the checker registration initial block so the
  // chronological assertion-control rules also cover pre-registration calls.
  initial begin : assertion_controller
    if (CONTROL) begin
      $assertoff(0, WakeupTime_A);
      $assertkill(0, WakeupTime_A);
    end
  end

  WakeupTime_A: assert property (@(posedge clk) 1'b0)
    else wakeup_failures++;
endinterface

module level_leaf(input logic clk);
  integer failures = 0;
  Leaf_A: assert property (@(posedge clk) 1'b0) else failures++;
endmodule

module level_parent(input logic clk);
  integer failures = 0;
  Parent_A: assert property (@(posedge clk) 1'b0) else failures++;
  level_leaf child(clk);
endmodule

module active_leaf(input logic clk, input logic start, input logic done);
  integer failures = 0;
  Active_A: assert property (@(posedge clk) start |=> done)
    else failures++;
endmodule

module top;
  logic clk = 0;
  logic start = 0;
  logic done = 0;
  adc_ctrl_sva_if #(.CONTROL(1)) selected(clk);
  adc_ctrl_sva_if #(.CONTROL(0)) retained(clk);
  level_parent levels(clk);
  active_leaf active(clk, start, done);

  task tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin : test
    // A relative scope selector with levels=1 controls Parent_A but not the
    // assertion one hierarchy level farther below it.
    $assertoff(1, levels);
    tick();
    if (selected.wakeup_failures != 0 || retained.wakeup_failures != 1)
      $fatal(1, "bare per-instance selector: %0d/%0d",
             selected.wakeup_failures, retained.wakeup_failures);
    if (levels.failures != 0 || levels.child.failures != 1)
      $fatal(1, "relative levels selector: %0d/%0d",
             levels.failures, levels.child.failures);

    // Relative child assertion path and explicit rooted path must coexist.
    $asserton(0, selected.WakeupTime_A);
    $assertoff(0, top.retained.WakeupTime_A);
    tick();
    if (selected.wakeup_failures != 1 || retained.wakeup_failures != 1)
      $fatal(1, "relative/full assertion selectors: %0d/%0d",
             selected.wakeup_failures, retained.wakeup_failures);

    // Kill followed immediately by On aborts the outstanding attempt but
    // permits later attempts.  All three calls use a relative child path.
    start = 1;
    tick();
    start = 0;
    $assertoff(0, active.Active_A);
    $assertkill(0, active.Active_A);
    $asserton(0, active.Active_A);
    tick();
    if (active.failures != 0)
      $fatal(1, "relative Off/Kill/On retained an old attempt: %0d",
             active.failures);
    start = 1;
    tick();
    start = 0;
    tick();
    if (active.failures != 1)
      $fatal(1, "relative On did not admit a new attempt: %0d",
             active.failures);

    $display("PASSED");
  end
endmodule

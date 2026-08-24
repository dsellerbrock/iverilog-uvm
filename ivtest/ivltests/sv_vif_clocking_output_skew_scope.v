// IEEE 1800-2017 14.4/14.16: a virtual-interface clocking output uses the
// skew and timeunit of the interface that defines the clocking block. This
// holds both for a buffered drive and for a drive issued after @(vif.cb).
interface skew_scope_if #(parameter integer DRIVE_SKEW = 3)
                         (input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  logic raw;
  clocking cb @(posedge clk);
    output #DRIVE_SKEW raw;
  endclocking
endinterface

module skew_scope_holder(input logic clk);
  timeunit 1ps;
  timeprecision 1ps;

  // The first sibling deliberately has a different specialization. A
  // virtual handle of the default type bound to z_good must not borrow
  // a_bad's 7ns skew merely because that instance is discovered first.
  skew_scope_if #(.DRIVE_SKEW(7)) a_bad(clk);
  skew_scope_if z_good(clk);
endmodule

module sv_vif_clocking_output_skew_scope;
  timeunit 1ps;
  timeprecision 1ps;

  logic clk = 1'b0;
  skew_scope_holder holder(clk);
  virtual skew_scope_if vif;
  integer failures = 0;

  always #5000 clk = ~clk;

  task check(input logic expected, input string label_text);
    if (holder.z_good.raw !== expected) begin
      failures++;
      $display("FAILED %s at %0t raw=%b expected=%b", label_text, $time,
               holder.z_good.raw, expected);
    end
  endtask

  initial begin
    vif = holder.z_good;
    holder.a_bad.raw = 1'b0;
    holder.z_good.raw = 1'b0;

    // Buffered at t=1ps, applied at the t=5000ps edge plus the interface's
    // 3ns skew. The caller's 1ps timeunit must not turn that into 3ps.
    #1;
    vif.cb.raw <= 1'b1;
    #5000;
    check(1'b0, "buffered drive before skew");
    #2998;
    check(1'b0, "buffered drive immediately before landing");
    #2;
    check(1'b1, "buffered drive after skew");

    // This drive takes the current-event branch. It must receive the same
    // defining-interface skew exactly once.
    @(vif.cb);
    vif.cb.raw <= 1'b0;
    #1;
    check(1'b1, "current-event drive before skew");
    #2998;
    check(1'b1, "current-event drive immediately before landing");
    #2;
    check(1'b0, "current-event drive after skew");

    if (failures != 0)
      $fatal(1, "%0d virtual clocking skew checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule

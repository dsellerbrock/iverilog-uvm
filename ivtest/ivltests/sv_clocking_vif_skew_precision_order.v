// VIF output skew is scaled using the defining interface's timeunit even when
// a later, otherwise unused VIF type tightens the design-wide precision.
interface clocking_coarse_first_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ns;
  logic raw;
  clocking cb @(posedge clk);
    output #2 raw;
  endclocking
endinterface

interface clocking_fine_later_if(input logic clk);
  timeunit 1ps;
  timeprecision 1ps;
  logic raw;
  clocking cb @(posedge clk);
    output #1 raw;
  endclocking
endinterface

// A reverse declaration order provides a control for type-population order.
interface clocking_fine_first_if(input logic clk);
  timeunit 1ps;
  timeprecision 1ps;
  logic raw;
endinterface

interface clocking_coarse_later_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ns;
  logic raw;
  clocking cb @(posedge clk);
    output #2 raw;
  endclocking
endinterface

module sv_clocking_vif_skew_precision_order;
  timeunit 1ns;
  timeprecision 1ns;

  logic clk = 1'b0;
  integer failures = 0;
  clocking_coarse_first_if coarse_first(clk);
  clocking_coarse_later_if coarse_control(clk);

  virtual clocking_coarse_first_if first_vif;
  virtual clocking_fine_later_if later_unused_vif;
  virtual clocking_fine_first_if first_unused_vif;
  virtual clocking_coarse_later_if control_vif;

  always #5 clk = ~clk;

  task check(input logic actual, input logic expected, input string label_text);
    if (actual !== expected) begin
      failures++;
      $display("FAILED %s at %0t actual=%b expected=%b", label_text,
               $time, actual, expected);
    end
  endtask

  initial begin
    first_vif = coarse_first;
    control_vif = coarse_control;
    coarse_first.raw = 1'b0;
    coarse_control.raw = 1'b0;

    #1;
    first_vif.cb.raw <= 1'b1;
    control_vif.cb.raw <= 1'b1;

    // The first positive edge is at 5ns and both outputs land at 7ns.
    #5;
    check(coarse_first.raw, 1'b0, "coarse-first before 2ns skew");
    check(coarse_control.raw, 1'b0, "reverse-order before 2ns skew");
    #2;
    check(coarse_first.raw, 1'b1, "coarse-first after 2ns skew");
    check(coarse_control.raw, 1'b1, "reverse-order after 2ns skew");

    if (failures != 0)
      $fatal(1, "%0d VIF precision-order checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule

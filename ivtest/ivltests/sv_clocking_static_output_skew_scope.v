// IEEE 1800-2017 14.4/14.16: a statically named clocking output uses the
// defining interface's parameters and timeunit for both buffered and
// current-event output skew.
interface static_skew_scope_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  localparam integer DRIVE_SKEW = 3;
  logic raw;
  clocking cb @(posedge clk);
    output #DRIVE_SKEW raw;
  endclocking
endinterface

module sv_clocking_static_output_skew_scope;
  timeunit 1ps;
  timeprecision 1ps;

  logic clk = 1'b0;
  static_skew_scope_if intf(clk);
  integer failures = 0;

  always #5000 clk = ~clk;

  task check(input logic expected, input string label_text);
    if (intf.raw !== expected) begin
      failures++;
      $display("FAILED %s at %0t raw=%b expected=%b", label_text, $time,
               intf.raw, expected);
    end
  endtask

  initial begin
    intf.raw = 1'b0;

    #1;
    intf.cb.raw <= 1'b1;
    #5000;
    check(1'b0, "buffered static drive before skew");
    #2998;
    check(1'b0, "buffered static drive immediately before landing");
    #2;
    check(1'b1, "buffered static drive after skew");

    @(intf.cb);
    intf.cb.raw <= 1'b0;
    #1;
    check(1'b1, "current static drive before skew");
    #2998;
    check(1'b1, "current static drive immediately before landing");
    #2;
    check(1'b0, "current static drive after skew");

    if (failures != 0)
      $fatal(1, "%0d static clocking skew checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule

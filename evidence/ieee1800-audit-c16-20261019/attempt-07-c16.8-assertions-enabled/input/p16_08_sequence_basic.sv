`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic a = 0, b = 0;
  always #5 clk = ~clk;

  sequence req_then_gnt;
    a ##1 b;
  endsequence : req_then_gnt

  assert property (@(posedge clk) req_then_gnt)
    else $fatal(1, "basic sequence failed");

  initial begin
    #1 a = 1'b1; b = 1'b1;
    #30 $display("PASSED");
    $finish(0);
  end
endmodule

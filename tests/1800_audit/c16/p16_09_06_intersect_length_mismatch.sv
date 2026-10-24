`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic start = 0, a = 0, b = 0, c = 0, d = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_intersect_unequal_lengths;
    @(posedge clk) start |-> ((a ##1 b) intersect (c ##2 d));
  endproperty
  assert property (p_intersect_unequal_lengths) else failures++;

  initial begin
    @(negedge clk); start = 1; a = 1; c = 1;
    @(negedge clk); start = 0; a = 0; c = 0; b = 1;
    @(negedge clk); b = 0; d = 1;
    @(negedge clk); d = 0;
    repeat (2) @(negedge clk);
    if (failures != 1) begin
      $display("FAILED: mismatched intersect failure count=%0d", failures);
      $finish(1);
    end
    $display("PASSED: §16.9.6 mismatched intersect lengths do not match");
    $finish(0);
  end
endmodule

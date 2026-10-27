`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic start_and = 0, a = 0, b = 0, c = 0, d = 0;
  logic start_intersect = 0, e = 0, f = 0, g = 0, h = 0;
  logic start_or = 0, i = 0, j = 0, k = 0, l = 0;
  always #5 clk = ~clk;

  property p_and;
    @(posedge clk) start_and |-> ((a ##1 b) and (c ##2 d));
  endproperty
  assert property (p_and) else $fatal(1, "unequal-length and should match");

  property p_intersect;
    @(posedge clk) start_intersect |-> ((e ##2 f) intersect (g ##2 h));
  endproperty
  assert property (p_intersect) else $fatal(1, "equal-length intersect should match");

  property p_or;
    @(posedge clk) start_or |-> ((i ##1 j) or (k ##2 l));
  endproperty
  assert property (p_or) else $fatal(1, "one matching or operand should match");

  initial begin
    // Drive away from posedge sampling to avoid Active/Preponed races.
    @(negedge clk); start_and = 1; a = 1; c = 1;
    @(negedge clk); start_and = 0; a = 0; c = 0; b = 1;
    @(negedge clk); b = 0; d = 1;
    @(negedge clk); d = 0; start_intersect = 1; e = 1; g = 1;
    @(negedge clk); start_intersect = 0; e = 0; g = 0;
    @(negedge clk); f = 1; h = 1;
    @(negedge clk); f = 0; h = 0; start_or = 1; i = 1;
    @(negedge clk); start_or = 0; i = 0; j = 1;
    @(negedge clk); j = 0;
    #20;
    $display("PASSED: §16.9.5 and, §16.9.6 intersect, §16.9.7 or");
    $finish(0);
  end
endmodule

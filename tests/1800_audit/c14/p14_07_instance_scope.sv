`timescale 1ns/1ps
module leaf(input logic clk, input logic d, output logic q);
  clocking cb @(posedge clk);
    input d;
    output q;
  endclocking

  always @(cb) cb.q <= cb.d;
endmodule

module test;
  logic clk = 0;
  always #5 clk = ~clk;
  logic d1 = 1, d2 = 0;
  logic q1, q2;

  leaf s1(clk, d1, q1);
  leaf s2(clk, d2, q2);

  initial begin
    @(s1.cb);
    @(s1.cb);
    #1;
    if (q1 !== 1'b1 || q2 !== 1'b0) begin
      $display("FAIL: expected q1=1 q2=0, got q1=%b q2=%b", q1, q2);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule

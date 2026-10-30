`timescale 1ns/1ps
module issue1536_clocking_zero_skew_2017;
  logic clk, d, q;
  clocking cb @(posedge clk);
    input #0 d;
    output #0 q;
  endclocking

  initial begin
    $display("PASSED");
    $finish;
  end
endmodule

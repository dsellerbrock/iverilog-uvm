`timescale 1ns/1ps
module top;
  logic clk, d, q;
  clocking cb @(posedge clk);
    input #0 d;
    output #0 q;
  endclocking

  initial begin
    clk = 0;
    #1 clk = 1;
    #1;
    $display("PASSED");
    $finish;
  end
endmodule

`timescale 1ns/1ps
module issue2339_numeric_input_skew_initializer;
  logic clk = 1'b0;
  logic initialized = 1'b1;
  logic overwritten = 1'b0;

  initial begin
    #8 overwritten = 1'b1;
    #2 clk = 1'b1;
  end

  clocking cb @(posedge clk);
    input #3 initialized;
    input #3 overwritten;
  endclocking

  always @(cb) begin
    if (cb.initialized !== 1'b1 || cb.overwritten !== 1'b0)
      $fatal(1, "numeric skew initializer sample mismatch: %b %b",
             cb.initialized, cb.overwritten);
    $display("PASSED");
  end
endmodule

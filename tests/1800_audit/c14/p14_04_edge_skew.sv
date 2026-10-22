`timescale 1ns/1ps
module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg dout = 0;

  clocking cb @(posedge clk);
    output negedge dout;
  endclocking

  initial begin
    @(cb); // posedge at t=5
    cb.dout <= 1'b1;
    #2; // t=7: posedge clk still high, dout must remain 0.
    if (dout !== 1'b0) begin
      $display("FAIL: output negedge drove early at t=7, got %b", dout);
      $finish(1);
    end
    #4; // t=11: negedge clk occurred at t=10, dout must be 1.
    if (dout !== 1'b1) begin
      $display("FAIL: output negedge expected 1 at t=11, got %b", dout);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule

`timescale 1ns/1ps
module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg din = 0;
  reg dout = 0;

  clocking cb @(posedge clk);
    input #2ns din;
    output #2ns dout;
  endclocking

  initial begin
    #2 din = 1; // din=1 at t=2
    #2 din = 0; // din=0 at t=4; clk posedge at t=5
    @(cb); // input #2ns samples at t=3ns where din was 1.
    if (cb.din !== 1'b1) begin
      $display("FAIL: input #2ns expected 1 (sampled at t=3ns), got %b", cb.din);
      $finish(1);
    end
    cb.dout <= 1'b1; // output #2ns drives at t=5+2=7ns.
    #1; // t=6: dout must still be 0
    if (dout !== 1'b0) begin
      $display("FAIL: output #2ns drove early at t=6, got %b", dout);
      $finish(1);
    end
    #2; // t=8: dout must be 1
    if (dout !== 1'b1) begin
      $display("FAIL: output #2ns expected 1 at t=8, got %b", dout);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule

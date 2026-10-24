`timescale 1ns/1ps
module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg din = 0;
  reg dout = 0;

  clocking cb @(posedge clk);
    default input #1step output #0;
    input din;
    output dout;
  endclocking

  initial begin
    #1;
    din = 1;
    @(cb); // posedge at t=5; #1step samples din=1 before the event.
    if (cb.din !== 1'b1) begin
      $display("FAIL: cb.din expected 1, got %b", cb.din);
      $finish(1);
    end
    cb.dout <= 1'b1; // output #0 drives in Re-NBA at t=5.
    #1; // t=6
    if (dout !== 1'b1) begin
      $display("FAIL: dout expected 1 at t=6, got %b", dout);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule

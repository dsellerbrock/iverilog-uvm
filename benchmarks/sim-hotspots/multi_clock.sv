`timescale 1ns/1ps
module top;
  genvar g;
  generate for (g = 0; g < 32; g = g + 1) begin : clocks
    reg clk;
    integer ticks;
    initial begin clk = 0; ticks = 0; end
    always #((g % 7) + 1) clk = ~clk;
    always @(posedge clk) ticks = ticks + 1;
  end endgenerate
  initial begin
    #320000;
    $display("ticks=%0d,%0d,%0d,%0d", clocks[0].ticks, clocks[7].ticks,
             clocks[15].ticks, clocks[31].ticks);
    $finish;
  end
endmodule

`timescale 1ns/1ns
module tb;
  bit clk;
  always #5 clk = ~clk;
  logic a = 1, b = 1, c = 1;
  initial begin #12 a = 0; #6 a = 1; end
  initial begin #17 b = 0; #6 b = 1; end
  initial #60 $finish;
  default clocking @(posedge clk); endclocking
  always @(negedge clk) begin
    assert property (a) else $display("C6a FAIL %0t", $time);
    assert property (b) else $display("C6b FAIL %0t", $time);
  end
endmodule

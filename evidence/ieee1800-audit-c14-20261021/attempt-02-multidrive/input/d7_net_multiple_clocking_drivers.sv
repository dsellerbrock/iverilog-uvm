`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  wire w;
  assign (weak0,weak1) w=0;
  clocking c1 @(posedge clk); output w; endclocking
  clocking c2 @(posedge clk); output w; endclocking
  initial begin @(c1) c1.w<=1; @(c2) c2.w<=0; @(c2) c2.w<=1'bz; end
  initial begin #1 $display("1 w=%b",w); #5 $display("6 w=%b",w); #10 $display("16 w=%b",w); #10 $display("26 w=%b",w); end
  initial #50 $finish;
endmodule

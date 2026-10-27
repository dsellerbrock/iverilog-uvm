module top;
  logic clk;
  sequence s(x); @(posedge clk) x; endsequence
  initial begin automatic bit av = 1; @(s(av)); end
endmodule

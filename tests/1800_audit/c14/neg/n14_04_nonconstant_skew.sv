module test;
  wire clk = 0;
  wire dout;
  int dyn_skew = 2;
  clocking cb @(posedge clk);
    output #dyn_skew dout;
  endclocking
endmodule

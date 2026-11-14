module issue2842_negative;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking
  initial begin ##(-1); $display("FAIL"); $finish; end
endmodule

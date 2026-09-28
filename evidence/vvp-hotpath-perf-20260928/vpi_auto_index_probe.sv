module t;
  logic clk = 0;
  logic [7:0] r;
  always_ff @(posedge clk) for (int j = 0; j < 4; j++) r[j] <= clk;
  integer k;
  always @(posedge clk) for (k = 0; k < 3; k++) r[4+k] <= 1;
  initial begin #1 clk = 1; #1 clk = 0; #1 clk = 1; #1 $finish; end
endmodule

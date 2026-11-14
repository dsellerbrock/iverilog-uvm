checker c(input logic clk);
  logic a, b;
  initial begin end
  always_ff @(posedge clk) begin end
  always_comb a = clk;
  always_latch if (clk) b = a;
  final begin end
endchecker
module issue3206_checker_always_good;
  logic clk = 0;
  c inst(clk);
  always #1 clk = ~clk;
  initial begin #2; $display("PASS"); $finish(0); end
endmodule

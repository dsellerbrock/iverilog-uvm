checker c(input logic clk);
  always @(posedge clk) begin end
  always (* keep = 1 *) @(posedge clk) begin end
  if (1) begin : gen
    always @(posedge clk) begin end
  end
endchecker
module issue3206_checker_always_bad;
  logic clk;
  c inst(clk);
endmodule

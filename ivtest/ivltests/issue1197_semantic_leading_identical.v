module issue1197_semantic_leading_identical;
  logic clk1 = 0;
  logic a = 1, b = 1;
  always #1 clk1 = ~clk1;

  a1: assert property (@(clk1) a and @(clk1) b);

  initial begin
    #1 $display("identical_clocks=accepted");
    $finish;
  end
endmodule

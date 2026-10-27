module issue1197_semantic_leading_identical;
  wire clk1;
  logic a = 1, b = 1;
  assign clk1 = 1'b0;

  a1: assert property (@(clk1) a and @(clk1) b);

  initial begin
    #1;
    $display("identical_clocks=accepted");
    $finish;
  end
endmodule

module test;
  logic clk = 0, a = 1;
  always #5 clk = ~clk;

  property p_correct;
    @(posedge clk) a;
  endproperty : p_mismatched

  assert property (p_correct);
  initial begin
    #20;
    $finish(0);
  end
endmodule

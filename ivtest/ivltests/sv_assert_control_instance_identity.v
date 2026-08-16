module assertion_leaf(input logic clk);
  integer failures;

  local_check: assert property (@(posedge clk) 1'b0)
    else failures++;
endmodule

module top;
  logic clk;
  assertion_leaf first(.clk(clk));
  assertion_leaf second(.clk(clk));

  initial begin
    $assertoff(0, top.first.local_check);

    #1 clk = 1;
    #1 clk = 0;
    if (first.failures != 0 || second.failures != 1)
      $fatal(1, "per-instance assertion off failed: %0d/%0d",
             first.failures, second.failures);

    $asserton(0, top.first.local_check);
    #1 clk = 1;
    #1 clk = 0;
    if (first.failures != 1 || second.failures != 2)
      $fatal(1, "per-instance assertion on failed: %0d/%0d",
             first.failures, second.failures);

    $display("PASSED");
  end
endmodule

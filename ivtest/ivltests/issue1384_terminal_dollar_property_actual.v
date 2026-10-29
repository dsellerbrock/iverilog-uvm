module issue1384_terminal_dollar_property_actual;
  logic clk = 0, start = 0, finish = 0;
  always #5 clk = ~clk;

  property unbounded(bound);
    @(posedge clk) start ##[1:bound] finish;
  endproperty

  c: cover property (unbounded($));

  initial begin
    @(negedge clk); start = 1; finish = 0;
    @(negedge clk); start = 0;
    @(negedge clk); finish = 1;
    @(negedge clk); finish = 0;
    repeat (2) @(negedge clk);
    if (_ivl_sva0_cnt0 != 1)
      $fatal(1, "terminal dollar property cover count=%0d",
             _ivl_sva0_cnt0);
    $display("PASS terminal dollar property actual");
    $finish(0);
  end
endmodule

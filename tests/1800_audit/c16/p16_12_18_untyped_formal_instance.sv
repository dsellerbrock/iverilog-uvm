module test;
  bit clk = 0;
  bit value = 1;

  always #5 clk = ~clk;

  property p_untyped(arg);
    arg;
  endproperty

  assert property (@(posedge clk) p_untyped(value));

  initial begin
    @(posedge clk); #1;
    $display("PASSED: §16.12.18 untyped property formal instance");
    $finish;
  end
endmodule

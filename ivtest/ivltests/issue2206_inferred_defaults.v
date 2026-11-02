module issue2206_inferred_defaults;
  logic clk = 0, rst = 1, a = 0;
  int failures = 0;
  always #5 clk = ~clk;

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  property p(event ev = $inferred_clock,
             bit dis = $inferred_disable);
    @(ev) disable iff (dis) a;
  endproperty

  ap: assert property (p()) else failures++;

  initial begin
    #12 rst = 0;
    #8 a = 1;
    #11;
    if (failures != 1) $fatal(1, "failures=%0d", failures);
    $display("PASSED");
    $finish;
  end
endmodule

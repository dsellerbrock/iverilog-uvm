// Probe for IEEE 1800-2017/2023 16.13.4(g): multiclock clock flow through
// an if-else property. The probe drives c through both values and keeps all
// branch operands true, so a valid implementation can compile and run it.
module p16_13_4_ifelse_clock_flow;
  bit clk = 0, clk1 = 0, clk2 = 0;
  bit a = 1, b = 1, c = 0, d = 1, e = 1, f = 1;
  integer passes = 0;

  always #5 clk = ~clk;
  always #7 clk1 = ~clk1;
  always #11 clk2 = ~clk2;
  always @(negedge clk) c = ~c;

  property mult_p8;
    @(posedge clk) a ##1 b |->
      if (c)
        (1 |=> @(posedge clk1) d)
      else
        e ##1 @(posedge clk2) f;
  endproperty

  assert property (mult_p8) begin
    passes++;
  end else $fatal(1, "multiclock if-else property failed");

  initial begin
    repeat (10) @(posedge clk);
    #1;
    if (passes < 3)
      $fatal(1, "expected multiclock if-else attempts, saw %0d", passes);
    $display("PASSED: IEEE 1800 16.13.4(g) multiclock if-else");
    $finish;
  end
endmodule

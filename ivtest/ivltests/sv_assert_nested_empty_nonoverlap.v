module test;
  bit clk, a = 1, b = 0, c = 0;
  int failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) a |=> (b[*0:1] |=> c))
    ; else failures++;

  initial begin
    // The empty b repetition must check c at the nested property's start
    // tick, when c is low.  c rises before the following tick so a delayed
    // check would incorrectly pass.
    a = 1;
    @(posedge clk);
    #1 a = 0;
    @(posedge clk);
    #1 c = 1;
    repeat (2) @(posedge clk);
    #1;
    if (failures != 1)
      $fatal(1, "empty nonoverlap failures=%0d, expected 1", failures);
    $display("PASSED");
    $finish(0);
  end
endmodule

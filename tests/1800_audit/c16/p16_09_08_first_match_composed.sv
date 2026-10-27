module test;
  logic clk = 0, a = 0, b = 0, c = 0;
  int passes = 0, failures = 0;
  always #5 clk = ~clk;

  // The earliest b match must commit the continuation to c one cycle later.
  assert property (@(posedge clk) a |-> (first_match(a ##[1:2] b) ##1 c))
    begin passes++; end
    else begin failures++; end

  initial begin
    // Earliest b@25 has no c@35. Later b@35 has c@45, but first_match
    // must discard that later match, so this attempt fails.
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0; c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);

    // This attempt's earliest b has the required c one cycle later.
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0; c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);

    if (passes != 1 || failures != 1)
      $fatal(1, "§16.9.8 expected passes=1 failures=1, got %0d/%0d",
             passes, failures);
    $display("PASSED: §16.9.8 first_match selected only the earliest match");
    $finish(0);
  end
endmodule

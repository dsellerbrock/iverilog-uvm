module test;
  bit clk = 0, a = 1, b = 1, c = 1, good = 1;
  bit disabled = 0;
  int passes = 0, failures = 0;
  int enabled_passes = 0, enabled_failures = 0;
  always #5 clk = ~clk;
  always @(negedge clk) begin
    good = ~good;
    a = ~a;
    b = ~b;
    c = ~c;
    disabled = ($time == 10);
  end

  assert property (@(posedge clk) (a ##0 (b ##1 c)[*0])[*0:1] |=> good)
    passes++; else failures++;
  assert property (@(posedge clk) disable iff (disabled)
                   (a ##0 (b ##1 c)[*0])[*0:1] |=> good)
    enabled_passes++; else enabled_failures++;

  initial begin
    #6;
    if (passes != 1 || failures != 0) $fatal(1, "tick 1: %0d %0d", passes, failures);
    #10;
    if (passes != 1 || failures != 1) $fatal(1, "tick 2: %0d %0d", passes, failures);
    #10;
    if (passes != 2 || failures != 1) $fatal(1, "tick 3: %0d %0d", passes, failures);
    #10;
    if (passes != 2 || failures != 2) $fatal(1, "tick 4: %0d %0d", passes, failures);
    if (enabled_passes != 2 || enabled_failures != 1)
      $fatal(1, "disable: %0d %0d", enabled_passes, enabled_failures);
    $display("PASSED");
    $finish(0);
  end
endmodule

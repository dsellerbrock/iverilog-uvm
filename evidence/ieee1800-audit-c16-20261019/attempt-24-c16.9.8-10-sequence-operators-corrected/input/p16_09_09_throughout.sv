module test;
  logic clk = 0, start = 0, done = 0, good = 0;
  int covered = 0, failures = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) (good throughout (start ##[1:2] done)))
    begin covered++; end
  assert property (@(posedge clk) start |-> (good throughout (start ##[1:2] done)))
    else begin failures++; end

  initial begin
    // A successful one-cycle wait; good holds at both endpoints.
    @(negedge clk); start = 1; good = 1;
    @(negedge clk); start = 0; done = 1;
    @(negedge clk); done = 0; good = 0;
    @(negedge clk);

    // The sequence completes after two cycles, but good drops only on the
    // intervening wait cycle, so throughout must reject this attempt.
    @(negedge clk); start = 1; good = 1;
    @(negedge clk); start = 0; good = 0;
    @(negedge clk); done = 1; good = 1;
    @(negedge clk); done = 0;
    @(negedge clk);

    if (covered != 1 || failures != 1)
      $fatal(1, "§16.9.9 expected cover=1 failures=1, got %0d/%0d",
             covered, failures);
    $display("PASSED: §16.9.9 throughout enforced the full match interval");
    $finish(0);
  end
endmodule

module main;
  bit clk = 0;
  bit a = 0, b = 0, c = 0, d = 0;
  bit e = 0, f = 0, g = 0, h = 0;
  int overlapped_failures = 0, nonoverlapped_failures = 0;

  always #5 clk = ~clk;

  // Both sequence languages are combinator trees; each side has a distinct
  // matching branch so the implication must retain both trees.
  assert property (@(posedge clk) (a or b) |-> (c or d))
    else overlapped_failures++;
  assert property (@(posedge clk) (e or f) |=> (g or h))
    else nonoverlapped_failures++;

  initial begin
    @(negedge clk);
    a = 1; d = 1; e = 1;
    @(negedge clk);
    a = 0; d = 0; b = 1; c = 1; e = 0; g = 1;
    @(negedge clk);
    b = 0; c = 0; a = 1; g = 0; e = 1;
    @(negedge clk);
    a = 0; e = 0;
    repeat (1) @(negedge clk);
    #1;
    if (overlapped_failures == 1 && nonoverlapped_failures == 1)
      $display("PASSED");
    else
      $display("FAILED: overlap=%0d nonoverlap=%0d",
        overlapped_failures, nonoverlapped_failures);
    $finish;
  end
endmodule

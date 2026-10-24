module test;
  logic clk = 0, x = 0, y = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) (b within (x ##[1:2] y)));
  assert property (@(posedge clk) x |-> (b within (x ##[1:2] y)))
    else begin failures++; end

  initial begin
    // The one-cycle b sequence is contained at the outer sequence's start.
    @(negedge clk); x = 1; b = 1;
    @(negedge clk); x = 0; b = 0; y = 1;
    @(negedge clk); y = 0;
    @(negedge clk);

    // It is contained in the middle of a two-cycle outer match.
    @(negedge clk); x = 1;
    @(negedge clk); x = 0; b = 1;
    @(negedge clk); b = 0; y = 1;
    @(negedge clk); y = 0;
    @(negedge clk);

    // The outer sequence matches, but b never occurs within it.
    @(negedge clk); x = 1;
    @(negedge clk); x = 0;
    @(negedge clk); y = 1;
    @(negedge clk); y = 0;
    @(negedge clk);

    // It is also contained at the outer match's end.
    @(negedge clk); x = 1;
    @(negedge clk); x = 0; y = 1; b = 1;
    @(negedge clk); y = 0; b = 0;
    @(negedge clk);

    if (_ivl_sva0_cnt0 != 3 || failures != 1)
      $fatal(1, "§16.9.10 expected cover=3 failures=1, got %0d/%0d",
             _ivl_sva0_cnt0, failures);
    $display("PASSED: §16.9.10 within matched start, middle, and end only");
    $finish(0);
  end
endmodule

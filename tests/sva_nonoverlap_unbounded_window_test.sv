module sva_nonoverlap_unbounded_window_test;
  bit clk, rst_n, trig, done;
  int passes, failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig |=> ##[0:$] done)
    passes++; else failures++;

  initial begin
    rst_n = 0;
    @(negedge clk);
    rst_n = 1;
    trig = 1;
    @(negedge clk);
    trig = 0;
    @(negedge clk);
    done = 1;
    @(negedge clk);
    done = 0;
    repeat (2) @(negedge clk);

    if (passes != 1 || failures != 0)
      $fatal(1, "nonoverlap unbounded window failed: %0d/%0d",
             passes, failures);
    $display("PASS: nonoverlap preserves the unbounded delay sentinel");
    $finish;
  end
endmodule

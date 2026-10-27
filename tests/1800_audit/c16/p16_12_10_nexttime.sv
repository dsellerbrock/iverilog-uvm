module test;
  bit clk = 0, start = 0, start_indexed = 0;
  bit a = 0, b = 0, c = 0;
  int next_failures, s_next_failures, indexed_failures, s_indexed_failures;
  always #5 clk = ~clk;

  property p_next;
    @(posedge clk) start |-> nexttime a;
  endproperty
  property p_s_next;
    @(posedge clk) start |-> s_nexttime a;
  endproperty
  property p_indexed;
    @(posedge clk) start_indexed |-> nexttime[2] b;
  endproperty
  property p_s_indexed;
    @(posedge clk) start_indexed |-> s_nexttime[2] c;
  endproperty
  assert property (p_next) else next_failures++;
  assert property (p_s_next) else s_next_failures++;
  assert property (p_indexed) else indexed_failures++;
  assert property (p_s_indexed) else s_indexed_failures++;

  initial begin
    @(negedge clk); start = 1;
    @(negedge clk); start = 0; a = 1;
    @(negedge clk); a = 0; start = 1;
    @(negedge clk); start = 0;
    @(negedge clk); start_indexed = 1;
    @(negedge clk); start_indexed = 0;
    @(negedge clk); b = 1; c = 1;
    repeat (2) @(negedge clk);
    if (next_failures != 1 || s_next_failures != 1 ||
        indexed_failures != 0 || s_indexed_failures != 0)
      $fatal(1, "§16.12.10 nexttime counts=%0d/%0d indexed=%0d/%0d",
             next_failures, s_next_failures, indexed_failures, s_indexed_failures);
    $display("PASSED: §16.12.10 weak/strong and indexed nexttime");
    $finish(0);
  end
endmodule

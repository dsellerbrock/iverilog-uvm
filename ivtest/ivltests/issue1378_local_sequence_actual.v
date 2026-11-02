module issue1378_local_sequence_actual;
  logic clk = 0;
  logic parent_start = 0, capture = 0, done = 0, finish = 0;
  logic [7:0] data = 0, observed = 0;
  always #5 clk = ~clk;

  sequence capture_subsequence(value);
    (capture, value = data) ##1 (done && observed == value);
  endsequence

  sequence parent_sequence;
    int local_value;
    parent_start ##1 capture_subsequence(local_value)
      ##1 (finish && observed == local_value);
  endsequence

  assert property (@(posedge clk) parent_start |-> parent_sequence)
    else $fatal(1, "local sequence actual did not flow out");

  initial begin
    @(negedge clk); parent_start = 1; data = 8'hA5;
    @(negedge clk); parent_start = 0; capture = 1;
    @(negedge clk); capture = 0; done = 1; observed = 8'hA5;
    @(negedge clk); done = 0; finish = 1;
    @(negedge clk); finish = 0;
    $display("PASSED");
    $finish;
  end
endmodule

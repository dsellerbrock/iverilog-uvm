module issue1378_local_sequence_actual;
  logic clk = 0;
  logic parent_start = 0, capture = 0, done = 0, finish = 0;
  logic [7:0] data = 0, observed = 0;
  int cover_hits = 0;

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
    else $fatal(1, "sequence local actual did not flow out");
  cover property (@(posedge clk) parent_sequence) cover_hits++;

  initial begin
    @(negedge clk);
    parent_start = 1;
    @(negedge clk);
    parent_start = 0;
    capture = 1;
    data = 8'hA5;
    @(negedge clk);
    capture = 0;
    data = 0;
    done = 1;
    observed = 8'hA5;
    @(negedge clk);
    done = 0;
    finish = 1;
    @(negedge clk);
    finish = 0;
    #1;
    if (cover_hits != 1)
      $fatal(1, "sequence match count=%0d", cover_hits);
    $display("PASSED");
    $finish(0);
  end
endmodule

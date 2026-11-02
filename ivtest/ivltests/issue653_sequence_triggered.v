module issue653_sequence_triggered;
  logic clk = 0, a = 1, b = 1, c = 1;
  time t_wait;
  bit triggered_at_end, triggered_later;

  always #5 clk = ~clk;

  sequence abc;
    @(posedge clk) a ##1 b ##1 c;
  endsequence

  initial begin
    if (abc.triggered)
      $fatal(1, "sequence triggered before an endpoint");
    wait (abc.triggered);
    t_wait = $time;
    triggered_at_end = abc.triggered;
    #1 triggered_later = abc.triggered;

    if (t_wait != 25 || !triggered_at_end || triggered_later)
      $fatal(1, "endpoint t=%0t same-slot=%b later=%b",
             t_wait, triggered_at_end, triggered_later);

    wait (abc.triggered);
    if ($time != 35 || !abc.triggered)
      $fatal(1, "second endpoint t=%0t triggered=%b", $time, abc.triggered);

    $display("PASS named sequence triggered: endpoint and time-step lifetime");
    $finish;
  end

  initial begin
    #50 $fatal(1, "wait(sequence.triggered) timed out");
  end
endmodule

module sv_assert_sequence_local_input;
  bit clk = 0, a = 1;
  int actual = 1;
  int direct_passes, direct_failures;
  int snapshot_passes, snapshot_failures;

  always #5 clk = ~clk;

  sequence with_local_input(local input int value);
    a && (value == 1);
  endsequence

  sequence with_local_snapshot(local input int value);
    a ##1 (value == 1);
  endsequence

  assert property (@(posedge clk) with_local_input(1))
    direct_passes++;
  else direct_failures++;

  assert property (@(posedge clk) with_local_snapshot(actual))
    snapshot_passes++;
  else snapshot_failures++;

  initial begin
    #6;
    if (direct_passes != 1 || direct_failures != 0)
      $fatal(1, "direct=%0d/%0d", direct_passes, direct_failures);
    actual = 0;
    #10;
    if (snapshot_passes != 1 || snapshot_failures != 0)
      $fatal(1, "snapshot=%0d/%0d", snapshot_passes, snapshot_failures);
    $display("PASSED");
    $finish(0);
  end
endmodule

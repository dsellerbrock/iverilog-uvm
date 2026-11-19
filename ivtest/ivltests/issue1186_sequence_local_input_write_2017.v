module issue1186_sequence_local_input_write;
  bit clk = 0;
  int value = 3;
  int observed;
  int direct_passes, ordered_passes, signed_passes;

  always #5 clk = ~clk;

  sequence direct_write(local input int local_value);
    (local_value == 1, local_value = 2) ##1 (local_value == 2);
  endsequence

  sequence ordered_writes(local input int value, copied);
    logic [31:0] expected = value * 2 + 1;
    (1'b1, value += value, copied = value + 1)
      ##2 (copied == expected && value == expected - 1 && observed == expected);
  endsequence

  sequence signed_write(local input logic signed [3:0] narrow);
    (narrow == 7, narrow += 1) ##1 (narrow == -8);
  endsequence

  assert property (@(posedge clk) direct_write(1))
    direct_passes++;
  else $fatal(1, "Direct local input write was lost");

  assert property (@(posedge clk) ordered_writes(value, 0))
    ordered_passes++;
  else $fatal(1, "Ordered updates did not use this attempt's local inputs");

  assert property (@(posedge clk) signed_write(7))
    signed_passes++;
  else $fatal(1, "Four-bit signed local input did not wrap to -8");

  initial begin
    #6;
    if (value !== 3) $fatal(1, "First attempt wrote back to its actual");
    value = 8;
    #10;
    if (direct_passes != 1 || signed_passes != 1)
      $fatal(1, "First completion counts: direct=%0d signed=%0d",
             direct_passes, signed_passes);
    if (value !== 8) $fatal(1, "Second attempt wrote back to its actual");
    value = 42;
    observed = 7;
    #10;
    if (ordered_passes != 1) $fatal(1, "First overlapping attempt did not pass");
    observed = 17;
    #10;
    if (ordered_passes != 2) $fatal(1, "Second overlapping attempt did not pass");
    if (value !== 42) $fatal(1, "Caller value changed");
    $display("PASSED");
    $finish(0);
  end
endmodule

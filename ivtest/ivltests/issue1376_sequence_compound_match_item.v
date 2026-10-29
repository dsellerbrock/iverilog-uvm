module issue1376_sequence_compound_match_item;
  logic clk = 0;
  logic a = 1, b = 1, c = 1;
  always #5 clk = ~clk;

  sequence valid_update;
    int local_value;
    (a, local_value = 0) ##1 (b, local_value += 1)
      ##1 (c && local_value == 1);
  endsequence

  assert property (@(posedge clk) valid_update)
    else $fatal(1, "compound sequence match item failed");

  initial begin
    repeat (5) @(negedge clk);
    $display("PASSED");
    $finish;
  end
endmodule

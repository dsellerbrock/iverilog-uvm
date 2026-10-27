module sv_sva_seq_incdec_match_item;
  logic clk = 0;
  always #5 clk = ~clk;

  sequence post_inc;
    int value;
    (1, value = 3) ##1 (1, value++) ##1 (value == 4);
  endsequence
  sequence pre_inc;
    int value;
    (1, value = 3) ##1 (1, ++value) ##1 (value == 4);
  endsequence
  sequence post_dec;
    int value;
    (1, value = 3) ##1 (1, value--) ##1 (value == 2);
  endsequence
  sequence pre_dec;
    int value;
    (1, value = 3) ##1 (1, --value) ##1 (value == 2);
  endsequence

  assert property (@(posedge clk) post_inc) else $fatal(1, "post-increment failed");
  assert property (@(posedge clk) pre_inc) else $fatal(1, "pre-increment failed");
  assert property (@(posedge clk) post_dec) else $fatal(1, "post-decrement failed");
  assert property (@(posedge clk) pre_dec) else $fatal(1, "pre-decrement failed");

  initial begin
    repeat (4) @(negedge clk);
    $display("PASSED");
    $finish;
  end
endmodule

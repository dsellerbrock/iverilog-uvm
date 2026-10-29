`default_nettype none
module issue1380_child_sequence_local_scope;
  logic clk, start, middle, finish;
  sequence child_sequence;
    logic hidden;
    (start, hidden = 1) ##1 middle;
  endsequence
  sequence parent_sequence;
    child_sequence ##1 (finish && hidden);
  endsequence
  assert property (@(posedge clk) parent_sequence);
endmodule

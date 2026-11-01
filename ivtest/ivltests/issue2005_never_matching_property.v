module impossible_sequence_property;
  logic clk=0;
  always #5 clk=~clk;
  sequence impossible_seq;
    (1'b1) intersect (1'b1 ##1 1'b1);
  endsequence
  ap: assert property (@(posedge clk) impossible_seq);
  initial begin repeat(2) @(negedge clk); $finish(0); end
endmodule

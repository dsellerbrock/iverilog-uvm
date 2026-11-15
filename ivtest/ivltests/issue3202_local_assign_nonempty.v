// IEEE 1800-2023 16.10: a local variable assignment may be attached to a
// subsequence that cannot match the empty word, such as the standard's own
// `a ##1 b[*0:1]`, or a repetition with a nonzero lower bound.
module top;
  logic clk = 0, a = 0, b = 0, c = 0;
  sequence s1;
    bit v;
    (a ##1 b[*0:1], v = 1) ##1 c;
  endsequence
  sequence s2;
    int n;
    a ##1 (b[*1:2], n = 0) ##1 c;
  endsequence
  sequence s3;
    int n;
    a ##1 ((b ##1 c)[*1:2], n = 0) ##1 c;
  endsequence
  assert property (@(posedge clk) s1 or 1);
  initial begin
    #1 clk = 1;
    #1 $display("PASSED");
  end
endmodule

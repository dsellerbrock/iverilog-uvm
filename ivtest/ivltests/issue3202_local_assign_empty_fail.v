// IEEE 1800-2023 16.10: "The subsequence to which a local variable
// assignment is attached shall not admit an empty match."
module top;
  logic clk, a, b, c;
  sequence s1;
    bit v;
    a ##1 (b[*0:1], v = 1) ##1 c;
  endsequence
  sequence s2;
    int n;
    a ##1 (b[*0:$], n += 1) ##1 c;
  endsequence
  sequence s3;
    int n;
    a ##1 (b[*0], n = 0) ##1 c;
  endsequence
  sequence s4;
    int n;
    a ##1 ((b ##1 c)[*0:2], n = 0) ##1 c;
  endsequence
endmodule

module top;
  logic clk, a, b, c, d, e;

  sequence unclocked;
    int x;
    ((a ##1 (b, x = 1)) or (c ##1 d)) ##1 (e && x);
  endsequence

  sequence clocked;
    int x;
    @(posedge clk) ((a ##1 (b, x = 1)) or (c ##1 d)) ##1 (e && x);
  endsequence
endmodule

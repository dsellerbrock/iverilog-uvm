module test;
  logic clk = 0, a = 0;
  always #5 clk = ~clk;

  // IEEE 1800-2017/2023 §16.11 forbids attaching a match item to a sequence
  // that admits an empty match.
  sequence s_empty;
    @(posedge clk) (a[*0:1], $display("matched empty"));
  endsequence

  cover property (s_empty);
endmodule

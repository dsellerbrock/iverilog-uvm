module top;
  bit clk = 0;
  bit a = 0, b = 0, c = 0, d = 0;

  always #5 clk = ~clk;
  sequence alternatives;
    (a ##1 b) or (c ##1 d);
  endsequence

  sequence together;
    (a ##1 b) and (c ##2 d);
  endsequence

  initial begin
    $display("PASSED");
    $finish(0);
  end
endmodule

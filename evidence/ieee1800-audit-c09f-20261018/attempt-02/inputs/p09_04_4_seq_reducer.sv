module top;
  logic clk = 0, a = 1, b = 1, c = 1;
  sequence abc; @(posedge clk) a ##1 b ##1 c; endsequence
  always #5 clk = ~clk;
  initial #40 $finish;
  assert property (abc) $display("ASSERT_PASS t=%0t", $time);
  initial begin
    wait (abc.triggered);
    $display("TRIGGERED t=%0t", $time);
  end
endmodule

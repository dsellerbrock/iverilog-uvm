`timescale 1ns/1ns
module p39;
  logic clk = 0, a = 0;
  always #5 clk = ~clk;

  pa: assert property (@(posedge clk) a);

  initial begin
    $probe39(0);
    #20 a = 1;
    #20 $report39;
    $finish;
  end
endmodule

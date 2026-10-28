module top;
  logic clk = 0;
  logic a = 1;
  always #5 clk = ~clk;

  p1: assert property (@(posedge clk) a);

  initial begin
    #1; $setup_control_info_cb();
    #1; $assertoff;
    #1; $asserton;
    @(posedge clk); #1; $assertkill;
    #1; $check_control_info_cb();
    $finish;
  end
endmodule

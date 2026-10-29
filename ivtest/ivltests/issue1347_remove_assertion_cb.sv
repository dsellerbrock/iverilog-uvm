module top;
  logic clk = 0, a = 1;
  always #5 clk = ~clk;
  p1: assert property (@(posedge clk) a);

  initial begin
    #1;
    $setup_remove_assertion_cb;
    #17;
    $check_remove_assertion_cb;
    $finish;
  end
endmodule

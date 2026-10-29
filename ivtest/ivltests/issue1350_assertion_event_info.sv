module top;
  logic clk = 0;
  logic a = 0, b = 1, d = 1;
  always #5 clk = ~clk;

  p1: assert property (@(posedge clk) a |-> b);
  p2: assert property (@(posedge clk) disable iff (d) a |-> b);

  initial begin
    #1; $setup_issue1350_callbacks();
    @(posedge clk); #1; $assertkill;
    #1; $check_issue1350_callbacks();
    $finish;
  end
endmodule

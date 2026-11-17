module top;
  bit clk;
  for (genvar i = 0; i < 2; i++) begin : G
    integer failures = 0;
    A: assert property (@(posedge clk) 1'b0) else failures++;
  end
  initial begin
    $assertoff(0, G[1].A);
    #1 clk = 1;
    #1;
    if (G[0].failures != 1 || G[1].failures != 0)
      $fatal(1, "incorrect assertion selection");
    $display("PASSED");
  end
endmodule

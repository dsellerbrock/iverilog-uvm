module sv_cycle_delay_expr_positive;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  initial begin
    #2;
    ##(0);
    $display("PASS");
    $finish;
  end
endmodule

module issue2842_zero;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking
  initial begin
    #2;
    ##(0);
    if ($time != 5) $fatal(1, "incorrect zero delay: %0t", $time);
    $display("PASS");
    $finish;
  end
endmodule

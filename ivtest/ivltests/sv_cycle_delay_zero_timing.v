module sv_cycle_delay_zero_timing;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  initial begin
    #2;
    ##0;
    if ($time != 5) $fatal(1, "pre-event ##0 did not wait: %0t", $time);

    #1;
    ##0;
    if ($time != 15) $fatal(1, "pre-event ##0 did not wait for next event: %0t", $time);

    ##0;
    if ($time != 15) $fatal(1, "same-step ##0 waited again: %0t", $time);
    $display("PASS");
    $finish;
  end
endmodule

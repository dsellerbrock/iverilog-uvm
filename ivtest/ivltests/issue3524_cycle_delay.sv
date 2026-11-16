module issue3524_cycle_delay;
  bit clk = 0;
  default clocking cb @(posedge clk); endclocking
  int n = 0, calls = 0;
  function automatic int count();
    calls++;
    return n;
  endfunction
  initial begin
    #3 clk = 1;
    #1 clk = 0;
    #3 clk = 1;
    #1 clk = 0;
    #3 clk = 1;
  end
  initial begin
    ##(n);
    if ($time != 3) $fatal(1, "variable zero: %0t", $time);
    ##n;
    if ($time != 3) $fatal(1, "same-step identifier: %0t", $time);
  end
  initial begin
    ##(count());
    if ($time != 3 || calls != 1) $fatal(1, "first zero: %0t %0d", $time, calls);
    ##(count());
    if ($time != 3 || calls != 2) $fatal(1, "same-step zero: %0t %0d", $time, calls);
    #1;
    n = 2;
    ##(count());
    if ($time != 11 || calls != 3) $fatal(1, "two events: %0t %0d", $time, calls);
    n = 0;
    #1;
    $display("PASS");
    $finish(0);
  end
  initial begin
    #30 $fatal(1, "timeout");
  end
endmodule

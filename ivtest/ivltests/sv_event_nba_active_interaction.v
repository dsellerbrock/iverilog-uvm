module nba_active_interaction;
  bit x, y, z, q;
  int direct_wakes, stable_wakes, blocking_wakes, staged_wakes;
  bit done;

  always @(negedge x) begin
    direct_wakes++;
    z = 1;
  end
  always @(negedge ((x | y) & ~z)) blocking_wakes++;
  always @(negedge (x | y)) stable_wakes++;
  always @(negedge (x | q)) begin
    staged_wakes++;
    q <= 1;
  end

  initial begin
    x = 1; y = 0; z = 0; q = 0;
    #1;
    x <= 0;
    y <= 1;
    #1;
    if (direct_wakes != 1) $fatal(1, "direct edge count=%0d", direct_wakes);
    if (stable_wakes != 0) $fatal(1, "stable expression pulsed=%0d", stable_wakes);
    if (blocking_wakes != 1) $fatal(1, "Active blocking interaction=%0d", blocking_wakes);
    if (staged_wakes != 1 || q != 1)
      $fatal(1, "NBA-to-NBA iteration staged=%0d q=%0b", staged_wakes, q);
    $display("PASSED");
    done = 1;
  end
  initial #20 if (!done) $fatal(1, "TIMEOUT");
endmodule

program renba_boolean_coalescing;
  logic x, y, z;
  int direct_wakes, stable_wakes, interaction_wakes;
  bit done;
  initial begin
    x = 1; y = 0; z = 0;
    fork
      begin forever begin @(negedge x); direct_wakes++; z = 1; end end
      begin forever begin @(negedge (x | y)); stable_wakes++; end end
      begin forever begin @(negedge ((x | y) & ~z)); interaction_wakes++; end end
    join_none
    #1; x <= 0; y <= 1;
    #1;
    if (direct_wakes != 1) $fatal(1, "direct=%0d", direct_wakes);
    if (stable_wakes != 0) $fatal(1, "stable=%0d", stable_wakes);
    if (interaction_wakes != 1) $fatal(1, "interaction=%0d", interaction_wakes);
    $display("PASSED"); done = 1;
  end
  initial #20 if (!done) $fatal(1, "TIMEOUT");
endprogram

class wide_cycle_item;
  randc bit [20:0] value;
  constraint legal_values { value inside {[0:1024]}; }
endclass

module test;
  initial begin
    wide_cycle_item item;
    bit [1024:0] seen;
    item = new;
    item.srandom(32'h4201025);
    seen = '0;

    for (int unsigned i = 0; i < 1025; i++) begin
      if (!item.randomize())
        $fatal(1, "randc failed at draw %0d", i);
      if (item.value > 1024 || seen[item.value])
        $fatal(1, "randc repeated or escaped its domain at draw %0d", i);
      seen[item.value] = 1'b1;
    end

    // 1,025 distinct values exhaust the exact feasible set; the next draw
    // must be a value from the new cycle.
    if (!item.randomize() || item.value > 1024 || !seen[item.value])
      $fatal(1, "randc did not start a new cycle after exhaustion");
    $display("PASSED");
  end
endmodule

// Exact constrained randc oracle: every aligned block is a permutation of
// the feasible set.  No assertion is made between adjacent cycle boundaries.
class randc_txn_constrained_item;
  randc bit [2:0] value;
  constraint legal_c { value inside {3'd1, 3'd3, 3'd5}; }
endclass

module test;
  initial begin
    randc_txn_constrained_item item;
    bit [7:0] seen;

    item = new;
    item.srandom(32'h1020_3040);
    for (int cycle = 0; cycle < 12; cycle++) begin
      seen = '0;
      for (int sample = 0; sample < 3; sample++) begin
        if (item.randomize() !== 1)
          $fatal(1, "constrained randc randomize failed");
        if (!(item.value inside {3'd1, 3'd3, 3'd5}))
          $fatal(1, "constrained randc emitted an infeasible value");
        if (seen[item.value])
          $fatal(1, "constrained randc repeated inside one feasible cycle");
        seen[item.value] = 1'b1;
      end
      if (seen !== 8'b0010_1010)
        $fatal(1, "constrained randc cycle was not exactly {1,3,5}");
    end

    $display("PASSED");
  end
endmodule

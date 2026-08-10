// A dynamic foreach forces two solver passes.  A forced final randc value is
// the sole history event: the following two-value feasible set must emit its
// other member, proving the actual post-pass-2 value was committed once.
class randc_txn_final_actual_item;
  randc bit [2:0] value;
  rand bit [3:0] data[];

  constraint shape_c { data.size() == 2; }
  constraint element_c { foreach (data[i]) data[i] == i + 1; }
endclass

module test;
  initial begin
    randc_txn_final_actual_item item;

    item = new;
    item.srandom(32'h0f1e_2d3c);
    for (int base = 0; base < 8; base += 2) begin
      if ((item.randomize() with { value == base; }) !== 1)
        $fatal(1, "forced two-pass randomize failed");
      if (item.value !== base[2:0])
        $fatal(1, "solver did not apply the forced final value");

      if ((item.randomize() with {
            value == base || value == base + 1;
          }) !== 1)
        $fatal(1, "two-value follow-up randomize failed");
      if (item.value !== (base + 1))
        $fatal(1, "final actual randc value was not committed exactly once");
      if (item.data.size() != 2 || item.data[0] !== 1 || item.data[1] !== 2)
        $fatal(1, "two-pass element solution was not committed");
    end

    $display("PASSED");
  end
endmodule

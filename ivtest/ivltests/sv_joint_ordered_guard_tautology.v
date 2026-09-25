class guard_tautology_leaf;
  rand bit gate, value;
  constraint c {
    solve gate before value;
    if (gate) value dist {0 := 1, 1 := 3};
  }
endclass

class guard_tautology_root;
  rand guard_tautology_leaf child;
  function new(); child = new; endfunction
endclass

module sv_joint_ordered_guard_tautology;
  guard_tautology_root root;
  int active, active_one, inactive_one;
  initial begin
    root = new;
    root.srandom(32'h47f1aa);
    repeat (4096) begin
      if (!root.randomize()) $fatal(1, "tautological guard support failed");
      if (root.child.gate) begin
        active++;
        active_one += root.child.value;
      end else inactive_one += root.child.value;
    end
    if (active < 1800 || active > 2300 ||
        active_one < 1350 || active_one > 1750 ||
        inactive_one < 800 || inactive_one > 1250)
      $fatal(1, "guard/value laws %0d %0d %0d",
             active, active_one, inactive_one);
    $display("PASSED");
  end
endmodule

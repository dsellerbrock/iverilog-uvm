class sv_joint_ordered_independent_randc_leaf;
  randc bit [1:0] cycle;
  constraint domain_c { cycle inside {0, 1, 2}; }
endclass
class sv_joint_ordered_independent_randc_item;
  rand bit sel;
  rand bit dep;
  rand sv_joint_ordered_independent_randc_leaf leaf;
  bit force_unsat;
  constraint dist_c { sel dist {0 := 0, 1 := 1}; }
  constraint relation_c { dep == sel; }
  constraint order_c { solve sel before dep; }
  constraint rollback_c { force_unsat -> leaf.cycle == 3; }
  function new; leaf = new; endfunction
endclass
module sv_joint_ordered_independent_randc;
  initial begin
    sv_joint_ordered_independent_randc_item item;
    bit [3:0] seen;
    bit [1:0] held;
    item = new;
    seen = 0;
    item.srandom(32'h1090_0001);
    if (!item.randomize()) $fatal(1, "first randomize failed");
    if (item.sel != 1 || item.dep != 1) $fatal(1, "ordered dist mismatch");
    seen[item.leaf.cycle] = 1;
    item.force_unsat = 1;
    if (item.randomize()) $fatal(1, "unsatisfiable randomize succeeded");
    item.force_unsat = 0;
    repeat (2) begin
      if (!item.randomize()) $fatal(1, "cycle randomize failed");
      if (item.sel != 1 || item.dep != 1) $fatal(1, "ordered dist mismatch");
      if (seen[item.leaf.cycle]) $fatal(1, "rollback consumed or cycle repeated");
      seen[item.leaf.cycle] = 1;
    end
    if (seen != 4'b0111) $fatal(1, "incomplete cycle %b", seen);
    held = item.leaf.cycle;
    item.leaf.cycle.rand_mode(0);
    if (!item.randomize() || item.leaf.cycle !== held)
      $fatal(1, "disabled randc mode failed");
    $display("PASSED");
    $finish(0);
  end
endmodule

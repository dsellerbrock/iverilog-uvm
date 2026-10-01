class sv_joint_coupled_randc_ordered_leaf;
  randc bit [1:0] cycle;
  constraint domain_c { cycle inside {0, 1, 2}; }
endclass
class sv_joint_coupled_randc_ordered_item;
  rand bit [1:0] sel;
  rand bit [1:0] dep;
  rand bit tail;
  rand sv_joint_coupled_randc_ordered_leaf leaf;
  bit force_unsat;
  constraint link_c { sel == leaf.cycle; dep == sel; }
  constraint dist_c { sel dist {0 := 1, 1 := 5, 2 := 9}; }
  constraint order_c { solve sel before dep; }
  constraint completion_c { tail == dep[0] || tail == !dep[0]; }
  constraint rollback_c { force_unsat -> dep == 3; }
  function new; leaf = new; endfunction
endclass
module sv_joint_coupled_randc_ordered;
  initial begin
    sv_joint_coupled_randc_ordered_item item;
    bit [3:0] seen;
    bit [1:0] held_cycle, held_sel, held_dep;
    item = new;
    item.srandom(32'h1110_0001);
    if (!item.randomize()) $fatal(1, "first randomize failed");
    seen = 0;
    seen[item.leaf.cycle] = 1;
    held_cycle = item.leaf.cycle; held_sel = item.sel; held_dep = item.dep;
    item.force_unsat = 1;
    if (item.randomize()) $fatal(1, "unsatisfiable call succeeded");
    if (item.leaf.cycle != held_cycle || item.sel != held_sel || item.dep != held_dep)
      $fatal(1, "failed call changed state");
    item.force_unsat = 0;
    repeat (2) begin
      if (!item.randomize()) $fatal(1, "cycle randomize failed");
      if (item.sel != item.leaf.cycle || item.dep != item.sel)
        $fatal(1, "coupling broken");
      if (seen[item.leaf.cycle]) $fatal(1, "cycle repeated");
      seen[item.leaf.cycle] = 1;
    end
    if (seen != 4'b0111) $fatal(1, "incomplete cycle %b", seen);
    held_cycle = item.leaf.cycle;
    item.leaf.cycle.rand_mode(0);
    if (!item.randomize() || item.leaf.cycle != held_cycle ||
        item.sel != held_cycle || item.dep != held_cycle)
      $fatal(1, "disabled cyclic state was not pinned");
    $display("PASSED");
    $finish(0);
  end
endmodule

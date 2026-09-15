class sv_joint_ordered_independent_randc_coupled_leaf;
  randc bit cycle;
endclass
class sv_joint_ordered_independent_randc_coupled_item;
  rand bit sel;
  rand bit dep;
  rand bit bridge;
  rand sv_joint_ordered_independent_randc_coupled_leaf leaf;
  constraint dist_c { sel dist {0 := 1, 1 := 1}; }
  constraint coupled_c { dep == sel; bridge == sel; leaf.cycle != bridge; }
  constraint order_c { solve sel before dep; }
  function new; leaf = new; endfunction
endclass
module sv_joint_ordered_independent_randc_coupled_fail;
  initial begin
    sv_joint_ordered_independent_randc_coupled_item item;
    item = new;
    item.sel = 0; item.dep = 1; item.bridge = 0; item.leaf.cycle = 1;
    if (item.randomize()) $fatal(1, "unsupported coupled solve succeeded");
    if (item.sel !== 0 || item.dep !== 1 || item.bridge !== 0 ||
        item.leaf.cycle !== 1)
      $fatal(1, "failed coupled solve changed object state");
    $display("PASSED");
    $finish(0);
  end
endmodule

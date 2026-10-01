class sv_joint_ordered_independent_randc_element_leaf;
  randc bit cycle[2];
  constraint domain_c { foreach (cycle[i]) cycle[i] inside {0, 1}; }
endclass
class sv_joint_ordered_independent_randc_element_item;
  rand bit sel;
  rand bit dep;
  rand sv_joint_ordered_independent_randc_element_leaf leaf;
  constraint dist_c { sel dist {0 := 0, 1 := 1}; }
  constraint relation_c { dep == sel; }
  constraint order_c { solve sel before dep; }
  function new; leaf = new; endfunction
endclass
module sv_joint_ordered_independent_randc_element;
  initial begin
    sv_joint_ordered_independent_randc_element_item item;
    bit first0, first1;
    item = new;
    item.srandom(32'h1090_0002);
    if (!item.randomize()) $fatal(1, "first randomize failed");
    first0 = item.leaf.cycle[0]; first1 = item.leaf.cycle[1];
    if (!item.randomize()) $fatal(1, "second randomize failed");
    if (item.sel != 1 || item.dep != 1) $fatal(1, "ordered dist mismatch");
    if (item.leaf.cycle[0] === first0 || item.leaf.cycle[1] === first1)
      $fatal(1, "element cycle repeated");
    $display("PASSED");
    $finish(0);
  end
endmodule

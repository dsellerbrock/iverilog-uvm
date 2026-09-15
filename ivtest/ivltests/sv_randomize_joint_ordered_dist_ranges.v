class joint_ordered_dist_range_leaf;
  rand bit value;
endclass
class joint_ordered_dist_range;
  rand bit gate;
  rand bit [1:0] value;
  rand joint_ordered_dist_range_leaf child;
  joint_ordered_dist_range_leaf alias_child;
  int posts;
  function new; child = new; alias_child = child; endfunction
  function void post_randomize; posts++; endfunction
  constraint order_c { solve gate before value; }
  constraint weights { value dist {[0:1] := 1, [2:3] :/ 6, 0 :/ 0}; }
  constraint fiber { alias_child.value == value[0]; }
endclass
class joint_ordered_dist_range_excluded extends joint_ordered_dist_range;
  constraint excluded { if (!gate) value == 1; }
endclass
module sv_randomize_joint_ordered_dist_ranges;
  joint_ordered_dist_range item = new;
  joint_ordered_dist_range_excluded bad = new, control = new;
  int gate_one, high, high2, high3;
  string bad_state, bad_child_state;
  initial begin
    item.srandom(32'h85a9e5);
    repeat (4096) begin
      if (!item.randomize() || item.child != item.alias_child ||
          item.child.value != item.value[0])
        $fatal(1, "ordered range relation");
      gate_one += item.gate;
      if (item.value >= 2) begin
        high++; high2 += item.value == 2; high3 += item.value == 3;
      end
    end
    // gate is uniform and independent. := gives [0:1] aggregate weight 2;
    // :/ gives [2:3] aggregate weight 6, uniformly within the chosen item.
    if (gate_one < 1850 || gate_one > 2250 || high < 2920 || high > 3220 ||
        high2 < 1350 || high2 > 1700 || high3 < 1350 || high3 > 1700 ||
        item.posts != 4096)
      $fatal(1, "range marginals gate=%0d high=%0d (%0d,%0d)",
             gate_one, high, high2, high3);
    item.value = 3;
    item.value.rand_mode(0);
    if (!item.randomize() || item.value != 3 || item.child.value != 1 ||
        item.posts != 4097)
      $fatal(1, "inactive dist subject or alias");
    item.value.rand_mode(1);
    bad.gate=0; bad.value=3; bad.child.value=1;
    control.gate=0; control.value=3; control.child.value=1;
    bad.srandom(32'h85bad); control.srandom(32'h85bad);
    bad.child.srandom(32'h85c11d); control.child.srandom(32'h85c11d);
    bad_state=bad.get_randstate();
    bad_child_state=bad.child.get_randstate();
    control.excluded.constraint_mode(0);
    if (bad.randomize() || bad.gate!=0 || bad.value!=3 ||
        bad.child.value!=1 || bad.posts!=0 ||
        bad.get_randstate()!=bad_state ||
        bad.child.get_randstate()!=bad_child_state)
      $fatal(1, "prefix exclusion was not atomic");
    bad.excluded.constraint_mode(0);
    if (!bad.randomize() || !control.randomize() || bad.gate!=control.gate ||
        bad.value!=control.value || bad.child.value!=control.child.value ||
        bad.posts!=1 || control.posts!=1)
      $fatal(1, "prefix exclusion consumed RNG");
    $display("PASSED");
  end
endmodule

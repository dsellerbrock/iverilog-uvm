typedef enum bit [1:0] {E0, E1, E2, E3} enum_t;
class nested_leaf;
  rand bit direct[-1:0];
  rand bit ordered[2:3];
  randc bit cyc[2:3];
  rand enum_t kind[1:2];
  bit state[4:5];
endclass
class nested_item;
  rand bit sel, dep, ordered_dep;
  rand nested_leaf leaf;
  constraint values {
    sel == leaf.cyc[2];
    dep == sel;
    leaf.direct[-1] == sel;
    ordered_dep == leaf.ordered[2];
    leaf.kind[1] inside {E1, E2};
    leaf.state[4] == 1;
  }
  constraint order_c { solve leaf.ordered[2] before ordered_dep; }
  function new; leaf = new; leaf.state[4] = 1; endfunction
endclass
module test;
  initial begin
    nested_item item;
    bit first;
    item = new;
    item.leaf.cyc[3].rand_mode(0);
    if (!item.randomize()) $fatal(1, "first randomize");
    first = item.leaf.cyc[2];
    if (item.dep != item.sel || item.leaf.direct[-1] != item.sel ||
        item.ordered_dep != item.leaf.ordered[2] ||
        !(item.leaf.kind[1] inside {E1, E2}) || item.leaf.state[4] != 1)
      $fatal(1, "nested constraints failed");
    if (!item.randomize()) $fatal(1, "second randomize");
    if (item.leaf.cyc[2] === first || item.dep != item.leaf.cyc[2])
      $fatal(1, "nested randc identity failed");
    $display("PASSED");
  end
endmodule

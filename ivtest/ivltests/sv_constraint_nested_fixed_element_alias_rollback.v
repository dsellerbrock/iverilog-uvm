class alias_leaf; randc bit cyc[1]; endclass
class alias_item;
  rand bit gate;
  rand alias_leaf leaf;
  alias_leaf alias_leaf_handle;
  bit force_fail;
  constraint links {
    leaf.cyc[0] == gate;
    alias_leaf_handle.cyc[0] == gate;
    force_fail -> leaf.cyc[0] != gate;
  }
  function new; leaf = new; alias_leaf_handle = leaf; endfunction
endclass
module test;
  initial begin
    alias_item item;
    bit first, held_gate, held_cyc;
    item = new;
    if (!item.randomize()) $fatal(1, "first");
    first = item.leaf.cyc[0];
    held_gate = item.gate; held_cyc = item.leaf.cyc[0];
    item.force_fail = 1;
    if (item.randomize()) $fatal(1, "unsatisfiable call succeeded");
    if (item.gate != held_gate || item.leaf.cyc[0] != held_cyc)
      $fatal(1, "failed call changed state");
    item.force_fail = 0;
    if (!item.randomize() || item.leaf.cyc[0] === first ||
        item.alias_leaf_handle.cyc[0] != item.gate)
      $fatal(1, "alias/history rollback failed");
    item.leaf.cyc[0].rand_mode(0);
    held_cyc = item.leaf.cyc[0];
    if (!item.randomize() || item.leaf.cyc[0] != held_cyc)
      $fatal(1, "element rand_mode ignored");
    $display("PASSED");
  end
endmodule

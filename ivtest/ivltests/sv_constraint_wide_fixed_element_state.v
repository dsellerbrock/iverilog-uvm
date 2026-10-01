class state_leaf; rand bit [127:0] value[2]; endclass
class state_item;
  rand state_leaf leaf;
  bit fail;
  constraint linked {
    leaf.value[0] == leaf.value[1] + 128'd1;
    fail -> leaf.value[0] == leaf.value[1];
  }
  function new; leaf = new; endfunction
endclass
module test;
  initial begin
    state_item item, control;
    string before_rng;
    bit [127:0] held0, held1;
    item = new; control = new;
    item.srandom(32'h12345678); control.srandom(32'h12345678);
    item.leaf.value[1].rand_mode(0);
    control.leaf.value[1].rand_mode(0);
    item.leaf.value[1] = 128'h80000000_00000000_00000000_00000007;
    control.leaf.value[1] = item.leaf.value[1];
    if (!item.randomize() || !control.randomize() ||
        item.leaf.value[0] !== 128'h80000000_00000000_00000000_00000008)
      $fatal(1, "wide inactive state pin failed");
    if (item.leaf.value[0] !== control.leaf.value[0] ||
        item.leaf.value[1] !== control.leaf.value[1])
      $fatal(1, "wide initial replay mismatch");
    held0 = item.leaf.value[0]; held1 = item.leaf.value[1];
    before_rng = item.get_randstate();
    item.fail = 1;
    if (item.randomize()) $fatal(1, "wide unsatisfiable call succeeded");
    if (item.leaf.value[0] !== held0 || item.leaf.value[1] !== held1 ||
        item.get_randstate() != before_rng)
      $fatal(1, "wide failed call was not atomic");
    item.fail = 0;
    if (!item.randomize() || !control.randomize() ||
        item.leaf.value[0] !== control.leaf.value[0] ||
        item.leaf.value[1] !== control.leaf.value[1])
      $fatal(1, "wide replay mismatch");
    $display("PASSED");
  end
endmodule

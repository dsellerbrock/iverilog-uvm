function automatic bit identity(input bit value);
  return value;
endfunction

function automatic bit [3:0] encode(input bit value);
  return value ? 4'hA : 4'h5;
endfunction

class pair_c;
  rand bit [1:0] enable;
  rand bit region[2];
  bit [1:0] target;
  bit contradict;
  int i = 99;
  constraint c {
    enable == target;
    foreach (region[i]) region[i] == identity(enable[i]);
    if (contradict) region[0] != enable[0];
  }
endclass

class offset_c;
  rand bit [3:2] enable;
  rand bit [3:0] region[3:2];
  bit [3:2] target;
  int i = 99;
  constraint c {
    enable == target;
    foreach (region[i]) region[i] == encode(enable[i]);
  }
endclass

class collision_c;
  rand bit [1:0] enable;
  rand bit region[2];
  function bit _ivl_0(input bit value);
    return value;
  endfunction
  constraint c {
    enable == 2'b10;
    foreach (region[_ivl_1])
      region[_ivl_1] == _ivl_0(enable[_ivl_1]);
  }
endclass

module test;
  pair_c pair_item;
  offset_c offset_item;
  collision_c collision_item;
  initial begin
    pair_item = new;
    pair_item.target = 2'b10;
    if (!pair_item.randomize() || pair_item.enable !== 2'b10
        || pair_item.region[1] !== 1 || pair_item.region[0] !== 0
        || pair_item.i !== 99)
      $fatal(1, "foreach argument 10: enable=%b region=%b%b i=%0d",
             pair_item.enable, pair_item.region[1], pair_item.region[0], pair_item.i);
    pair_item.target = 2'b01;
    if (!pair_item.randomize() || pair_item.enable !== 2'b01
        || pair_item.region[1] !== 0 || pair_item.region[0] !== 1
        || pair_item.i !== 99)
      $fatal(1, "foreach argument 01: enable=%b region=%b%b i=%0d",
             pair_item.enable, pair_item.region[1], pair_item.region[0], pair_item.i);
    pair_item.contradict = 1;
    if (pair_item.randomize())
      $fatal(1, "contradictory selected argument was ignored");

    offset_item = new;
    offset_item.target = 2'b10;
    if (!offset_item.randomize() || offset_item.enable !== 2'b10
        || offset_item.region[3] !== 4'hA || offset_item.region[2] !== 4'h5
        || offset_item.i !== 99)
      $fatal(1, "nonzero foreach indices: enable=%b region=%b%b i=%0d",
             offset_item.enable, offset_item.region[3], offset_item.region[2], offset_item.i);
    collision_item = new;
    if (!collision_item.randomize() || collision_item.enable !== 2'b10
        || collision_item.region[1] !== 1 || collision_item.region[0] !== 0)
      $fatal(1, "generated wrapper name collided with source names");
    $display("PASSED");
  end
endmodule

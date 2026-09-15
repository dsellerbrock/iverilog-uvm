class dynamic_leaf; rand bit value[2]; endclass
class dynamic_item;
  rand int index;
  rand dynamic_leaf leaf;
  constraint bad { leaf.value[index] == 1; }
  function new; leaf = new; endfunction
endclass
module test; initial begin dynamic_item item; item = new; void'(item.randomize()); end endmodule

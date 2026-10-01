class bounds_leaf; rand bit value[-1:0]; endclass
class bounds_item;
  rand bounds_leaf leaf;
  constraint bad { leaf.value[1] == 1; }
  function new; leaf = new; endfunction
endclass
module test; initial begin bounds_item item; item = new; void'(item.randomize()); end endmodule

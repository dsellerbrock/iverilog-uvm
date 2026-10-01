class access_leaf; protected rand bit value[1]; endclass
class access_item;
  rand access_leaf leaf;
  constraint bad { leaf.value[0] == 1; }
  function new; leaf = new; endfunction
endclass
module test; initial begin access_item item; item = new; void'(item.randomize()); end endmodule

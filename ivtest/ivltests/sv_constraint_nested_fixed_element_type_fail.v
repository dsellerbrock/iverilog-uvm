class type_leaf; string value[1]; endclass
class type_item;
  rand type_leaf leaf;
  constraint bad { leaf.value[0] == "x"; }
  function new; leaf = new; endfunction
endclass
module test; initial begin type_item item; item = new; void'(item.randomize()); end endmodule

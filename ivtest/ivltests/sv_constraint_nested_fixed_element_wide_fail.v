class wide_leaf; rand bit [64:0] value[1]; endclass
class wide_item;
  rand wide_leaf leaf;
  constraint bad { leaf.value[0] == 65'd1; }
  function new; leaf = new; endfunction
endclass
module test; initial begin wide_item item; item = new; void'(item.randomize()); end endmodule

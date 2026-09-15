class missing_leaf; rand bit present[2]; endclass
class missing_item;
  rand missing_leaf leaf;
  rand bit missing[2];
  constraint bad { leaf.missing[0] == 1; }
  function new; leaf = new; endfunction
endclass
module test; initial begin missing_item item; item = new; void'(item.randomize()); end endmodule

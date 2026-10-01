class leaf; rand bit [64:0] value[1]; endclass
class item;
  rand leaf child;
  constraint c { child.value[0] dist {65'd0 := 1, 65'd1 := 1}; }
  function new; child = new; endfunction
endclass
module test; initial begin item x; x = new; if (x.randomize()) $fatal(1, "wide dist accepted"); #0; end endmodule

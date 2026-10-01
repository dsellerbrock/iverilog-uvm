class leaf; randc bit [64:0] value[1]; endclass
class item;
  rand leaf child;
  constraint c { child.value[0] == 65'd1; }
  function new; child = new; endfunction
endclass
module test; initial begin item x; x = new; if (x.randomize()) $fatal(1, "wide randc accepted"); #0; end endmodule

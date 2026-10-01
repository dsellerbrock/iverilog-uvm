class leaf; rand bit [64:0] value[1]; endclass
class item;
  rand bit gate;
  rand leaf child;
  constraint c {
    solve child.value[0] before gate;
    gate == (child.value[0] == 65'd1);
  }
  function new; child = new; endfunction
endclass
module test; initial begin item x; x = new; if (x.randomize()) $fatal(1, "wide order accepted"); #0; end endmodule

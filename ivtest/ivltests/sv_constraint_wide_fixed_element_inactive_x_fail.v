class leaf; rand logic [64:0] value[1]; endclass
class item;
  rand leaf child;
  constraint c { child.value[0] == 65'd0; }
  function new;
    child = new;
    child.value[0].rand_mode(0);
  endfunction
endclass
module test; initial begin item x; x = new; if (x.randomize()) $fatal(1, "inactive X value accepted"); #0; end endmodule

class item;
  rand logic [64:0] value[1];
  constraint c { value[0] == 65'h1x; }
endclass
module test; initial begin item x; x = new; void'(x.randomize()); end endmodule

package issue3359_impure_pkg;
  import "DPI-C" function int issue3359_impure(input int value);
endpackage
class item;
  rand int x;
  constraint values { x == issue3359_impure_pkg::issue3359_impure(3); }
endclass
module top;
  item obj;
  initial begin obj = new; if (!obj.randomize()) $fatal; end
endmodule

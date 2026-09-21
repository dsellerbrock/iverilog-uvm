// A real value cannot index a fixed-size unpacked array.
class selected_real;
  real selected;
  rand int a[2][3];
  constraint c { foreach (a[selected][j]) a[0][j] == j; }
endclass
module main;
  selected_real obj;
  initial begin obj = new; if (!obj.randomize()) $fatal(1, "randomize"); end
endmodule

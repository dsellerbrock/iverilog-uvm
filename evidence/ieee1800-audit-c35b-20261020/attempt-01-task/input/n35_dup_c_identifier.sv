module n35_dup_c_identifier;
  import "DPI-C" c_add2 = function int f1(int a, int b);
  import "DPI-C" c_add2 = function real f2(real a);
endmodule

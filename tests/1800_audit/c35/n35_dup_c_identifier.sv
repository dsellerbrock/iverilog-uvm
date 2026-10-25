module n35_dup_c_identifier;
  import "DPI-C" c_add2 = function int f1(int a, int b);
  import "DPI-C" c_add2 = function real f2(real a);
  initial begin
    $display("I1 %0d", f1(3, 4));
    $display("I2 %0.1f", f2(2.0));
  end
endmodule

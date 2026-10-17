module top;
  class A; int j = 5; endclass
  class X extends A; int x; endclass
  A b2, b3; X xt, x2;
  initial begin xt = new; xt.x = 3; b2 = xt; b3 = new b2; $display("COPIED");
    $display("%s", ($cast(x2, b3) && x2.x == 3 && x2 != xt) ? "PASS dyn_type" : "FAIL dyn_type"); end
endmodule

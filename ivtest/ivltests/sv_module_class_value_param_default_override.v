class C; endclass
module M #(type T = C, T p = 4) ();
endmodule
module top;
  M #(.T(int)) u();
  initial $display("%0d", u.p);
endmodule

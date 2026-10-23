class C; endclass
module M #(type T = C, T p = 4) ();
endmodule
module top;
  M u();
endmodule

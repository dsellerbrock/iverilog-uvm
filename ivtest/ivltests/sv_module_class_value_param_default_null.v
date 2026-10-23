class C; endclass
module M #(type T = C, T p = null) ();
endmodule
module top;
  M u();
  initial $display("PASSED");
endmodule

module s6_static_method_localparam;
  class C;
    static function int f(input int a); return a + 1; endfunction
  endclass
  function automatic int cf(input int a); return C::f(a); endfunction
  localparam int P = cf(4);
  initial $display("S6 P=%0d", P);
endmodule

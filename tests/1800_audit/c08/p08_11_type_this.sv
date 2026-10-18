module top;
  class TT; int a = 4;
    function int f(); var type(this) t; t = this; return t.a; endfunction
  endclass
  TT h;
  initial begin h = new; $display("%s 8.11.type_this", h.f() == 4 ? "PASS" : "FAIL"); end
endmodule

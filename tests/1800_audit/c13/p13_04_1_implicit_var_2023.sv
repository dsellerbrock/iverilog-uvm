module top;
  class A; int member = 1; endclass
  typedef struct { bit [15:0] v; } s_t;
  A a;
  function A F; int member; a = new(); return a; endfunction
  function s_t G(); G.v = 16'hA5C3; endfunction
  initial begin
    $display("%s 13.4.1.F().member_implicit (%0d)", F().member == 1 ? "PASS" : "FAIL", F().member);
    $display("%s 13.4.1.implicit_var_index", G().v[11:8] == 4'h5 ? "PASS" : "FAIL");
  end
endmodule

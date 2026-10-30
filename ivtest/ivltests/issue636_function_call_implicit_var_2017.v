module issue636_function_call_implicit_var;
  class A; int member = 1; endclass
  typedef struct { bit [15:0] v; } s_t;
  A a;
  function A F; int member; a = new(); return a; endfunction
  function s_t G(); G.v = 16'hA5C3; endfunction
  initial begin
    if (F().member != 1) $fatal(1, "F().member");
    if (G().v[11:8] != 4'h5) $fatal(1, "G().v[11:8]");
    $display("passed");
  end
endmodule

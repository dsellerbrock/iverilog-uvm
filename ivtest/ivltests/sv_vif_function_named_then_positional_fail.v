// IEEE 1800-2017/2023 13.5.4: positional arguments shall precede named
// arguments. The shared named-argument mapper must count this diagnostic as a
// compile error instead of silently substituting the later formal's default.
interface vif_function_named_then_positional_if;
  function automatic int combine(input int first, input int second = 9);
    return first * 10 + second;
  endfunction
endinterface

module sv_vif_function_named_then_positional_fail;
  vif_function_named_then_positional_if concrete();
  virtual vif_function_named_then_positional_if vif;
  int result;

  initial begin
    vif = concrete;
    result = vif.combine(.first(3), 4);
  end
endmodule

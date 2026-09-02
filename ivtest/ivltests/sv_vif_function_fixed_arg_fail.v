// IEEE 1800-2017/2023 13.5 and 25.9: fixed-unpacked-array arguments need a
// selected-candidate array marshaller. Keep the unsupported boundary loud.
typedef int vif_function_fixed_arg_pair_t[0:1];

interface vif_function_fixed_arg_if;
  function automatic int sum(input vif_function_fixed_arg_pair_t value);
    return value[0] + value[1];
  endfunction
endinterface

module sv_vif_function_fixed_arg_fail;
  vif_function_fixed_arg_if concrete();
  virtual vif_function_fixed_arg_if vif;
  vif_function_fixed_arg_pair_t value = '{3, 4};
  int result;

  initial begin
    vif = concrete;
    result = vif.sum(value);
  end
endmodule

// IEEE 1800-2017/2023 13.4.1 and 25.9: a fixed-unpacked-array return requires
// selected-frame array copy-out. Keep the unsupported boundary explicit.
typedef int vif_function_fixed_return_pair_t[0:1];

interface vif_function_fixed_return_if;
  function automatic vif_function_fixed_return_pair_t make();
    vif_function_fixed_return_pair_t value = '{5, 6};
    return value;
  endfunction
endinterface

module sv_vif_function_fixed_return_fail;
  vif_function_fixed_return_if concrete();
  virtual vif_function_fixed_return_if vif;
  vif_function_fixed_return_pair_t result;

  initial begin
    vif = concrete;
    result = vif.make();
  end
endmodule

// IEEE 1800-2017/2023 13.5 and 25.9: output/inout/ref virtual-interface
// function arguments require selected-instance copy-back. Until that lowering
// exists, reject the call explicitly instead of accepting it without copy-back.
interface vif_function_copyback_arg_if;
  function automatic int update(output int value);
    value = 17;
    return value;
  endfunction
endinterface

module sv_vif_function_copyback_arg_fail;
  vif_function_copyback_arg_if concrete();
  virtual vif_function_copyback_arg_if vif;
  int value;
  int result;

  initial begin
    vif = concrete;
    result = vif.update(value);
  end
endmodule

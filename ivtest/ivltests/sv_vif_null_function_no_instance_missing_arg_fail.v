// IEEE 1800-2017/2023 13.5.3 and 25.9: the compiler must validate a
// declaration-only virtual-interface function signature even when the design
// has no concrete interface instance. A null receiver does not hide a missing
// required argument behind its later run-time error.
interface vif_null_function_no_instance_missing_arg_if;
  function automatic int required(input int value);
    return value;
  endfunction
endinterface

class vif_null_function_no_instance_missing_arg_cfg;
  virtual vif_null_function_no_instance_missing_arg_if vif;

  function int probe();
    return vif.required();
  endfunction
endclass

module sv_vif_null_function_no_instance_missing_arg_fail;
  vif_null_function_no_instance_missing_arg_cfg cfg;

  initial begin
    cfg = new;
    $display("UNREACHABLE result=%0d", cfg.probe());
  end
endmodule

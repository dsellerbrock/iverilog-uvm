// IEEE 1800-2017/2023 25.9 and 13.4.1: an uninitialized virtual-interface
// function receiver remains a run-time error when the selected design has no
// concrete instance of the interface. The string-only len() use also requires
// the declaration-only path to retain the function's declared return type,
// imported formal type, explicit-actual conversion, and an interface-member
// default expression.
package vif_null_function_no_instance_pkg;
  typedef logic [5:0] code_t;
endpackage

interface vif_null_function_no_instance_if;
  import vif_null_function_no_instance_pkg::*;
  code_t default_code = 6'd3;

  function automatic string name(input code_t code = default_code);
    return "unexpected";
  endfunction
endinterface

class vif_null_function_no_instance_cfg;
  virtual vif_null_function_no_instance_if vif;

  function int probe(
      input bit use_default,
      input vif_null_function_no_instance_pkg::code_t code);
    if (use_default)
      return vif.name().len();
    return vif.name(code).len();
  endfunction
endclass

module sv_vif_null_function_no_instance_fail;
  vif_null_function_no_instance_cfg cfg;

  initial begin
    cfg = new;
    $display("UNREACHABLE length=%0d", cfg.probe(1'b0, 6'd7));
    $fatal(1, "null VIF function call returned instead of failing");
  end
endmodule

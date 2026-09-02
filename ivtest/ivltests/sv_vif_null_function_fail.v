// IEEE 1800-2017/2023 25.9 and 13.4.1: calling a value-returning
// function through a null virtual interface is a run-time error. A compatible
// concrete instance in the design must not become an implicit receiver.
interface vif_null_function_if;
  logic value = 1'b1;

  function automatic logic sample();
    return value;
  endfunction
endinterface

module sv_vif_null_function_fail;
  vif_null_function_if concrete();
  virtual vif_null_function_if vif;
  logic result;

  initial begin
    result = vif.sample();
    $display("UNREACHABLE result=%0b", result);
    $fatal(1, "null VIF function call returned instead of failing");
  end
endmodule

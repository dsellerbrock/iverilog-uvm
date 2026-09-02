// IEEE 1800-2017/2023 25.9: a null virtual interface remains null even when
// its complete parameter specialization has a resolvable method signature.
// Calling that method must terminate at run time rather than return a stub.
interface param_vif_null_if #(parameter WIDTH = 8);
  function automatic logic [WIDTH-1:0] echo(
      input logic [WIDTH-1:0] value);
    echo = value;
  endfunction
endinterface

module sv_vif_parameter_specialization_null_fail;
  virtual interface param_vif_null_if #(17) vif;
  logic [16:0] result;

  initial begin
    result = vif.echo(17'h1beef);
    $display("UNREACHABLE result=%h", result);
  end
endmodule

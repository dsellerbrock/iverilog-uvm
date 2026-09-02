// IEEE 1800-2017/2023 25.9 and 13.4.1: a virtual interface declared
// without an explicit parameter assignment denotes the default
// specialization. An unrelated concrete specialization must not determine
// the function signature or contribute a dispatch candidate.
interface vif_function_parameterized_if #(
    parameter int WIDTH = 8
) (input logic [WIDTH-1:0] value);
  function automatic logic [WIDTH-1:0] sample(
      input logic [WIDTH-1:0] bias = '0);
    return value + bias;
  endfunction
endinterface

module sv_vif_function_parameterized_candidate_filter;
  logic [15:0] wide_value = 16'hcafe;
  logic [7:0] default_value = 8'h25;

  // Put the incompatible specialization first so a global "first method"
  // lookup cannot accidentally select the declaration's ABI.
  vif_function_parameterized_if #(16) unrelated(wide_value);
  vif_function_parameterized_if selected(default_value);
  virtual vif_function_parameterized_if vif;
  logic [7:0] result;

  initial begin
    vif = selected;
    result = vif.sample(8'h03);
    if (result !== 8'h28)
      $fatal(1, "unrelated interface specialization poisoned VIF dispatch");
    $display("PASSED");
  end
endmodule

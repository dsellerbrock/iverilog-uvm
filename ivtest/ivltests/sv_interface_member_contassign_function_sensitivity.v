// A continuous assignment selected for interface-member lowering must include
// dependencies read inside a called function, not only the call arguments.
interface function_sensitivity_if;
  logic source;
endinterface

module function_sensitivity_bridge(
  function_sensitivity_if bus,
  input logic hidden,
  output wire result
);
  function automatic logic combine(input logic argument);
    return argument ^ hidden;
  endfunction

  assign result = combine(bus.source);
endmodule

module sv_interface_member_contassign_function_sensitivity;
  function_sensitivity_if bus();
  logic hidden;
  wire result;

  function_sensitivity_bridge dut(
    .bus(bus),
    .hidden(hidden),
    .result(result)
  );

  initial begin
    bus.source = 1'b0;
    hidden = 1'b0;
    #1;
    if (result !== 1'b0)
      $fatal(1, "initial result is stale: %b", result);

    // Only the function-body dependency changes here.
    hidden = 1'b1;
    #1;
    if (result !== 1'b1)
      $fatal(1, "function-body dependency did not wake assignment: %b", result);

    // The interface-member argument remains dynamically watched as well.
    bus.source = 1'b1;
    #1;
    if (result !== 1'b0)
      $fatal(1, "interface-member argument did not wake assignment: %b", result);

    $display("PASSED");
  end
endmodule

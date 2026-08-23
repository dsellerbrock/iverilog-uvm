interface param_transfer_if #(parameter int WIDTH = 8);
  logic [WIDTH-1:0] request;
  logic [WIDTH-1:0] response;

  modport endpoint(
    input request,
    output response
  );
endinterface

module param_transfer_leaf(param_transfer_if.endpoint req_if);
  always_comb req_if.response = req_if.request;
endmodule

// Forwarding a parameterized interface port must preserve the concrete
// specialization selected by the eventual interface instance.
module param_transfer_forward(param_transfer_if.endpoint req_if);
  param_transfer_leaf leaf(.req_if(req_if));
endmodule

module synth_parameterized_interface_member_netlist(
  input  logic [15:0] in16,
  input  logic [23:0] in24,
  output logic [15:0] out16,
  output logic [23:0] out24
);
  param_transfer_if #(.WIDTH(16)) bus16();
  param_transfer_if #(.WIDTH(24)) bus24();

  param_transfer_leaf direct(.req_if(bus16.endpoint));
  param_transfer_forward forwarded(.req_if(bus24.endpoint));

  assign bus16.request = in16;
  assign bus24.request = in24;
  assign out16 = bus16.response;
  assign out24 = bus24.response;
endmodule

module synth_parameterized_interface_member;
  logic [15:0] in16;
  logic [23:0] in24;
  logic [15:0] out16;
  logic [23:0] out24;

  synth_parameterized_interface_member_netlist dut(.*);

  // Keep the value checker in the post-synthesis VVP image without asking the
  // synthesis pass to lower the testbench process itself.
  (* ivl_synthesis_off *)
  initial begin
    in16 = 16'habcd;
    in24 = 24'hc0ffee;
    #1;
    if (out16 !== 16'habcd || out24 !== 24'hc0ffee)
      $fatal(1, "FAILED out16=%h out24=%h", out16, out24);
    $display("PASSED out16=%h out24=%h", out16, out24);
  end
endmodule

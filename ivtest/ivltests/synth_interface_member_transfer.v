interface transfer_if;
  logic [7:0] data_out;
  logic [7:0] data_in;
  logic [1:0][3:0] packed_out;
  logic [1:0][3:0] packed_in;

  modport source(
    output data_out, packed_out,
    input data_in, packed_in
  );

  modport sink(
    input data_out, packed_out,
    output data_in, packed_in
  );
endinterface

module transfer_bridge(
  transfer_if.source external_source,
  transfer_if.sink external_sink
);
  transfer_if local_bus();

  assign external_source.data_out = local_bus.data_out;
  assign external_source.packed_out = local_bus.packed_out;
  assign local_bus.data_in = external_source.data_in;
  assign local_bus.packed_in = external_source.packed_in;

  assign external_sink.data_in = local_bus.data_in;
  assign external_sink.packed_in = local_bus.packed_in;
  assign local_bus.data_out = external_sink.data_out;
  assign local_bus.packed_out = external_sink.packed_out;
endmodule

// Forwarding a modport through another module must preserve the eventual
// concrete interface-instance binding for synthesis.
module transfer_forward(
  transfer_if.source external_source,
  transfer_if.sink external_sink
);
  transfer_bridge inner(
    .external_source(external_source),
    .external_sink(external_sink)
  );
endmodule

module synth_interface_member_transfer_netlist(
  input logic [7:0] sink_data_out,
  input logic [1:0][3:0] sink_packed_out,
  input logic [7:0] source_data_in,
  input logic [1:0][3:0] source_packed_in,
  output logic [7:0] source_data_out,
  output logic [1:0][3:0] source_packed_out,
  output logic [7:0] sink_data_in,
  output logic [1:0][3:0] sink_packed_in
);
  transfer_if source_bus();
  transfer_if sink_bus();

  transfer_bridge dut(
    .external_source(source_bus.source),
    .external_sink(sink_bus.sink)
  );

  assign sink_bus.data_out = sink_data_out;
  assign sink_bus.packed_out = sink_packed_out;
  assign source_bus.data_in = source_data_in;
  assign source_bus.packed_in = source_packed_in;

  assign source_data_out = source_bus.data_out;
  assign source_packed_out = source_bus.packed_out;
  assign sink_data_in = sink_bus.data_in;
  assign sink_packed_in = sink_bus.packed_in;
endmodule

module synth_interface_member_forward_netlist(
  input logic [7:0] sink_data_out,
  input logic [1:0][3:0] sink_packed_out,
  input logic [7:0] source_data_in,
  input logic [1:0][3:0] source_packed_in,
  output logic [7:0] source_data_out,
  output logic [1:0][3:0] source_packed_out,
  output logic [7:0] sink_data_in,
  output logic [1:0][3:0] sink_packed_in
);
  transfer_if source_bus();
  transfer_if sink_bus();

  transfer_forward dut(
    .external_source(source_bus.source),
    .external_sink(sink_bus.sink)
  );

  assign sink_bus.data_out = sink_data_out;
  assign sink_bus.packed_out = sink_packed_out;
  assign source_bus.data_in = source_data_in;
  assign source_bus.packed_in = source_packed_in;

  assign source_data_out = source_bus.data_out;
  assign source_packed_out = source_bus.packed_out;
  assign sink_data_in = sink_bus.data_in;
  assign sink_packed_in = sink_bus.packed_in;
endmodule

module transfer_array_bridge(
  transfer_if.source external_source[2],
  transfer_if.sink external_sink[2]
);
  for (genvar i = 0; i < 2; i++) begin : gen_transfer
    assign external_source[i].data_out = external_sink[i].data_out;
    assign external_sink[i].data_in = external_source[i].data_in;
  end
endmodule

module synth_interface_member_array_netlist(
  input logic [7:0] sink_data_out_0,
  input logic [7:0] sink_data_out_1,
  input logic [7:0] source_data_in_0,
  input logic [7:0] source_data_in_1,
  output logic [7:0] source_data_out_0,
  output logic [7:0] source_data_out_1,
  output logic [7:0] sink_data_in_0,
  output logic [7:0] sink_data_in_1
);
  transfer_if source_bus[2]();
  transfer_if sink_bus[2]();

  transfer_array_bridge dut(
    .external_source(source_bus),
    .external_sink(sink_bus)
  );

  assign sink_bus[0].data_out = sink_data_out_0;
  assign sink_bus[1].data_out = sink_data_out_1;
  assign source_bus[0].data_in = source_data_in_0;
  assign source_bus[1].data_in = source_data_in_1;

  assign source_data_out_0 = source_bus[0].data_out;
  assign source_data_out_1 = source_bus[1].data_out;
  assign sink_data_in_0 = sink_bus[0].data_in;
  assign sink_data_in_1 = sink_bus[1].data_in;
endmodule

// One synthesis root exercises direct binding, formal-to-formal forwarding,
// interface arrays, scalar packed members, and multidimensional packed
// members in the same elaborated design.
module synth_interface_member_all_netlist;
  logic [7:0] data_in;
  logic [1:0][3:0] packed_in;
  wire [7:0] direct_source_data_out;
  wire [1:0][3:0] direct_source_packed_out;
  wire [7:0] direct_sink_data_in;
  wire [1:0][3:0] direct_sink_packed_in;
  wire [7:0] forward_source_data_out;
  wire [1:0][3:0] forward_source_packed_out;
  wire [7:0] forward_sink_data_in;
  wire [1:0][3:0] forward_sink_packed_in;
  wire [7:0] array_source_data_out_0;
  wire [7:0] array_source_data_out_1;
  wire [7:0] array_sink_data_in_0;
  wire [7:0] array_sink_data_in_1;

  synth_interface_member_transfer_netlist direct(
    .sink_data_out(data_in),
    .sink_packed_out(packed_in),
    .source_data_in(data_in),
    .source_packed_in(packed_in),
    .source_data_out(direct_source_data_out),
    .source_packed_out(direct_source_packed_out),
    .sink_data_in(direct_sink_data_in),
    .sink_packed_in(direct_sink_packed_in)
  );

  synth_interface_member_forward_netlist forwarded(
    .sink_data_out(data_in),
    .sink_packed_out(packed_in),
    .source_data_in(data_in),
    .source_packed_in(packed_in),
    .source_data_out(forward_source_data_out),
    .source_packed_out(forward_source_packed_out),
    .sink_data_in(forward_sink_data_in),
    .sink_packed_in(forward_sink_packed_in)
  );

  synth_interface_member_array_netlist arrayed(
    .sink_data_out_0(data_in),
    .sink_data_out_1(data_in),
    .source_data_in_0(data_in),
    .source_data_in_1(data_in),
    .source_data_out_0(array_source_data_out_0),
    .source_data_out_1(array_source_data_out_1),
    .sink_data_in_0(array_sink_data_in_0),
    .sink_data_in_1(array_sink_data_in_1)
  );

endmodule

module synth_interface_member_transfer;
  transfer_if source_bus();
  transfer_if sink_bus();

  transfer_bridge dut(
    .external_source(source_bus.source),
    .external_sink(sink_bus.sink)
  );

  initial begin
    sink_bus.data_out = 8'h5a;
    sink_bus.packed_out = 8'hc3;
    source_bus.data_in = 8'ha5;
    source_bus.packed_in = 8'h3c;
    #1;
    if (source_bus.data_out !== 8'h5a ||
        source_bus.packed_out !== 8'hc3 ||
        sink_bus.data_in !== 8'ha5 ||
        sink_bus.packed_in !== 8'h3c) begin
      $fatal(1, "FAILED data source=%h/%h sink=%h/%h",
             source_bus.data_out, source_bus.packed_out,
             sink_bus.data_in, sink_bus.packed_in);
    end
    $display("PASSED");
  end
endmodule

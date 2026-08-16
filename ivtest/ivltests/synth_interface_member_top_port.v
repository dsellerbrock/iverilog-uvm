interface synth_top_port_if;
  logic [7:0] source;
  logic [7:0] sink;
  modport bridge(input source, output sink);
endinterface

// A selected synthesis root has no parent interface instance. Its modport
// members must nevertheless remain full-width structural top-level signals;
// they are not one-bit simulation handles and are not an error boundary.
module synth_interface_member_top_port(
  synth_top_port_if.bridge bus
);
  assign bus.sink = bus.source;
endmodule

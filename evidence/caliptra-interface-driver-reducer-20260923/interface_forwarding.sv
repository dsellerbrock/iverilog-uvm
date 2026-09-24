interface bus_if;
  logic req;
  // synthesis translate_off
  task reset(); req = 1'b0; endtask
  // synthesis translate_on
  modport sink(input req);
endinterface
module sink(bus_if.sink bus);
  logic observed;
  always_comb observed = bus.req;
endmodule
module legal_top(input logic source);
  bus_if bus();
  assign bus.req = source;
  sink u_sink(bus);
endmodule

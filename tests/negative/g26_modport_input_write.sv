// NEGATIVE: writing an interface member that the port's modport lists
// as INPUT must be rejected (IEEE 1800-2017 25.5).
interface neg_bus;
  logic [7:0] data;
  modport slv (input data);
endinterface

module neg_consumer (neg_bus.slv s);
  initial s.data = 8'hFF;   // illegal: data is input in modport slv
endmodule

module g26_modport_input_write;
  neg_bus b();
  neg_consumer c (b);
endmodule

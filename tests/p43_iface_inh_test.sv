// G29: b.mst modport-select bind syntax in port connections.
// Pre-fix: `consumer c(.b_in(b.mst))` — using iface_instance.modport
// as a port-connection expression — caused "Net b.mst is not defined
// in this context" because elaborate_lnet_common_ could not find a
// net for `b` when `b` was instantiated with explicit port connections.
// Fix: synthesise a typed wire for the interface instance on demand.
`timescale 1ns/1ps

interface bus_if(input logic clk);
  logic [7:0] data;
  logic       valid;
  modport mst (output data, output valid);
  modport slv (input  data, input  valid);
endinterface

module producer(bus_if b_out);
  initial begin end
endmodule

module consumer(bus_if b_in);
  initial begin end
endmodule

module top;
  logic clk = 0;
  bus_if b(.clk(clk));
  producer p(.b_out(b.mst));
  consumer c(.b_in(b.slv));
  initial begin
    $display("PASS: iface.modport port-connection expression accepted");
    $finish;
  end
endmodule

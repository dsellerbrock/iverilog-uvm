// G27: module ports declared as `interface_name.modport_name`
// (implicit modport selection at the call site).
// Pre-fix: the port type was parsed but the connection p(.m(iface))
// failed because the interface instance net was not found.
// This test verifies that the modport-typed port accepts a plain
// interface instance as a connection.
`timescale 1ns/1ps

interface bus_if(input logic clk);
  logic [7:0] data;
  logic       valid;
  modport master (output data, output valid);
  modport slave  (input  data, input  valid);
endinterface

module producer(bus_if.master m);
  initial begin end
endmodule

module consumer(bus_if.slave s);
  initial begin end
endmodule

module top;
  logic clk = 0;
  bus_if dut_if(.clk(clk));
  producer p(.m(dut_if));
  consumer c(.s(dut_if));
  initial begin
    $display("PASS: modport-typed ports accept plain interface connections");
    $finish;
  end
endmodule

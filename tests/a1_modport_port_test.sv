// Phase 63a / A1: module ports declared with `interface_name.modport`
// header must parse without syntax error.
//
// Pre-fix: parser at parse.y rejected `module m(if_name.modport_name p)`
// with "syntax error" at the modport dot.  vif_smoke.sv:7 hit this.
//
// This test verifies the parse-and-elaborate path; the modport name is
// captured into interface_type_t::modport but not yet used for
// direction enforcement (follow-up).
`timescale 1ns/1ps

interface bus_if(input logic clk);
  logic [7:0] data;
  logic       valid;
  modport master (output data, output valid);
  modport slave  (input  data, input  valid);
endinterface

module producer(bus_if.master m);
  initial begin
    // Just exercising that the port type parses.
    // Real driving would need bidirectional resolution which is a
    // separate gap.
  end
endmodule

module consumer(bus_if.slave s);
  initial begin
  end
endmodule

module top;
  logic clk = 0;
  bus_if dut_if(.clk(clk));
  producer p(.m(dut_if));
  consumer c(.s(dut_if));
  initial begin
    $display("PASS: modport-typed module ports parsed and elaborated");
    $finish;
  end
endmodule

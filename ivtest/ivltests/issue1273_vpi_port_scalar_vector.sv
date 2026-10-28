interface bus; logic [7:0] data; modport mp(input data); endinterface
module child(input logic a, output logic [3:0] y, bus p, bus.mp q,
             input logic [0:0] one, input logic [3:0] z); endmodule
module top;
  logic a, one;
  logic [3:0] y;
  bus b();
  child u(.a(a), .y(), .p(b), .q(b), .one(one), .z());
  initial begin #0; $probe_port_widths; $finish; end
endmodule

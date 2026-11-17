// IEEE 1800-2017/2023 30.3: a specify block "shall appear inside a module
// declaration". Owner ruling on #1299 (2026-11-16): one inside an
// interface is illegal; keep rejecting it (#3652).
interface timing_if(input wire a, output wire y);
  assign y = a;
  specify (a => y) = (1, 1); endspecify
endinterface
module top;
  wire a, y;
  timing_if intf(a, y);
endmodule

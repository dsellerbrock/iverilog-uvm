// Issue #1264 (IEEE 1800-2023 37.10, 37.11): instance arrays are VPI
// objects. $probe checks them.
interface bus_if;
  logic v;
endinterface

module leaf(input logic a, input logic b);
endmodule

module top;
  logic a, b;
  leaf inst[2:4](.a(a), .b(b));
  leaf rev[1:0](.a(a), .b(b));
  leaf one(.a(a), .b(b));
  bus_if buses[0:1]();
  initial #1 $probe;
endmodule

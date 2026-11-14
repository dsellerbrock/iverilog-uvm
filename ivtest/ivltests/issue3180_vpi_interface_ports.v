// Issue #3180 (IEEE 1800-2023 37.14 detail 5, 37.15): interface and modport
// ports connect through vpiRefObj handles whose vpiActual is the interface
// instance or its modport. $probe checks them from VPI.
interface bus_if;
  logic v;
  modport m(input v);
endinterface

module inner(bus_if.m q);
endmodule

module leaf(bus_if b, bus_if.m bm, input wire d);
  inner n(b);
endmodule

module top;
  bus_if i();
  wire w;
  leaf l(i, i, w);
  initial #1 $probe;
endmodule

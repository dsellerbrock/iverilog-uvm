`timescale 1ns/1ns
interface SBus;
  logic req;
endinterface
module m(virtual SBus v);
endmodule
module top;
  SBus s();
  m u(s);
endmodule

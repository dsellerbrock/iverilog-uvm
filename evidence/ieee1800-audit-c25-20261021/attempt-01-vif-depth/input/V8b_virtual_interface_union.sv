`timescale 1ns/1ns
interface SBus;
  logic req;
endinterface
typedef union {
  virtual SBus v;
  int i;
} u_t;
module top;
  u_t u;
endmodule

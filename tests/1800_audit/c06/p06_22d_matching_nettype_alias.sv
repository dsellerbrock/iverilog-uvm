package p06_22_nettypes;
  nettype logic [3:0] payload_nt;
  nettype payload_nt payload_alias_nt;
endpackage
import p06_22_nettypes::*;
module sink(input payload_nt data);
  always @* $display("DATA=%0h", data);
endmodule
module top;
  payload_nt a;
  payload_alias_nt b;
  assign a = 4'ha;
  assign b = 4'h5;
  sink u0(a);
  sink u1(b);
  initial #1 $finish;
endmodule

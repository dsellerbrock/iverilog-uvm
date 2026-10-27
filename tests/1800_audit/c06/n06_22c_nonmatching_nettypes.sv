package n06_22_nonmatching_nettypes;
  nettype logic [3:0] first_nt;
  nettype logic [3:0] second_nt;
endpackage
import n06_22_nonmatching_nettypes::*;
module sink(input first_nt data);
endmodule
module top;
  second_nt other;
  sink u0(other);
endmodule

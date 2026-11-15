// NEG-DIAG: A charge strength shall only be used with a trireg net
// IEEE 1800-2023 6.3.2.1: "The charge strength specification shall be used
// only with trireg nets." (This replaces m13_trireg_unsupported, which
// required trireg itself to be rejected; trireg is supported since #878.)
module top;
  wire (small) w;
  initial $display("FAILED");
endmodule

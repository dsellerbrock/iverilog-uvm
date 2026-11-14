// IEEE 1800-2023 6.3.2.1: "The charge strength specification shall be used
// only with trireg nets." This must not compile.
module top;
   wire (small) w;
   initial $display("FAILED");
endmodule

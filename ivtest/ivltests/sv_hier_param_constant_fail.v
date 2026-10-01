// A parameter reached through an instance path is a hierarchical reference
// and is not allowed in a constant expression (IEEE 1800-2017/2023 11.2.1).
// Accepted only under -gcommercial-unsafe.
module gen #(parameter int BlkLen = 128) ();
endmodule
module test;
  gen #(.BlkLen(64)) u_gen ();
  localparam int W = test.u_gen.BlkLen;
endmodule

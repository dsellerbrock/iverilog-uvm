// Resource boundary of the current eager lowering. This legal source must
// receive an explicit unsupported diagnostic instead of exhausting memory.
module test;
  logic data[];
  logic selected[];
  initial selected = data[0 +: 65537];
endmodule

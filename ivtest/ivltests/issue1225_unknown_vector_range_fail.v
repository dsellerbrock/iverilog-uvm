module issue1225_unknown_vector_range_fail;
  localparam X = 1'bx;
  localparam Z = 1'bz;

  logic [X:0] unknown_msb;
  logic [0:X] unknown_lsb;
  logic [Z:0] high_impedance_msb;
  logic [0:Z] high_impedance_lsb;
endmodule

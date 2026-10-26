module issue1225_unknown_range_fail;
  localparam X = 1'bx;
  localparam Z = 1'bz;
  logic [X:0] invalid_msb;
  logic [1:Z] invalid_lsb;
endmodule

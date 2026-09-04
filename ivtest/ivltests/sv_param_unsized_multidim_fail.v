// IEEE 1800-2017/2023 6.20.2 -- the residual half of
// sv_param_unsized_unpacked_dimension. A SINGLE unsized parameter dimension
// takes its size from the initializer. A MULTI-dimensional unsized declaration
// does not: a flat element count says nothing about how the dimensions should
// be split, so inferring one would be a guess. It stays a loud error.
module main;
  parameter int GRID[][] = '{'{1, 2}, '{3, 4}};
  initial $display("%0d", GRID[0][0]);
endmodule

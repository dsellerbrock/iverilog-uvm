module issue3788_bad_row(input wire [7:0] p[1:0]);
endmodule

module issue3788_bad;
  wire [7:0] a[3:2][7:4][1:1];
  // Four words total, but the selected dimensions have sizes 4 and 1.
  issue3788_bad_row bad_shape[1:0](a[2][7:4]);
  issue3788_bad_row bad_bounds[1:0](a[2][8:7]);
  issue3788_bad_row bad_direction[1:0](a[2][6:7]);
  issue3788_bad_row bad_bound_type[1:0](a[2][7.0:6]);
endmodule

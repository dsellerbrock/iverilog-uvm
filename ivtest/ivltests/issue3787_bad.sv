module issue3787_bad_matrix(input wire [7:0] d [2][3]);
endmodule

module issue3787_bad;
  logic [7:0] wrong_shape [2][3][2];
  bit [7:0] wrong_type [2][2][3];
  // Same total word count, with swapped suffix extents.
  issue3787_bad_matrix shape [0:1] (wrong_shape);
  // Same shape and packed width, with a different state domain.
  issue3787_bad_matrix elem_type [0:1] (wrong_type);
endmodule

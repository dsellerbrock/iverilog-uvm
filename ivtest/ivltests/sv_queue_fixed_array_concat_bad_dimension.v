module sv_queue_fixed_array_concat_bad_dimension;
  bit [7:0] matrix[2][2];
  bit [7:0] q[$];
  initial q = {matrix};
endmodule

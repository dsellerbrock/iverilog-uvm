// These calls are legal IEEE 1800-2017 array-method forms, but their
// aggregate element representations need a later recursive equality track.
// Keep them loud rather than flattening, truncating, or returning an empty
// queue silently.
typedef struct {
  int left;
  int right;
} unpacked_pair_t;

module multidimensional_fixed_unique;
  int matrix[2:3][7:8];

  initial begin
    matrix.unique();
    matrix.unique_index();
  end
endmodule

module unpacked_struct_queue_unique;
  unpacked_pair_t values[$];
  unpacked_pair_t result[$];
  int indexes[$];

  initial begin
    result = values.unique;
    indexes = values.unique_index;
  end
endmodule

module unpacked_struct_fixed_unique;
  unpacked_pair_t values[-1:1];
  unpacked_pair_t result[$];
  int indexes[$];

  initial begin
    result = values.unique;
    indexes = values.unique_index;
  end
endmodule

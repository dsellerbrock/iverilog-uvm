module sv_ustruct_member_defaults_unused_shape_fail;
  // The typedef is intentionally unused. These are legal declaration shapes,
  // but applying their member defaults is not implemented yet, so each must
  // retain the same explicit unsupported boundary as a consumed type.
  typedef struct {
    byte fixed_data[4] = '{4{1}};
    byte dynamic_data[] = '{1, 2};
    byte queue_data[$] = '{3, 4};
    byte assoc_data[integer] = '{default: 5};
  } unused_shape_t;
endmodule

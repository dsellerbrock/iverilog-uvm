module sv_ustruct_member_defaults_unused_shape_fail;
  // The typedef is intentionally unused. These dynamic shapes remain outside
  // the supported member-default subset even when their typedef is unused.
  typedef struct {
    byte dynamic_data[] = '{1, 2};
    byte queue_data[$] = '{3, 4};
    byte assoc_data[integer] = '{default: 5};
  } unused_shape_t;
endmodule

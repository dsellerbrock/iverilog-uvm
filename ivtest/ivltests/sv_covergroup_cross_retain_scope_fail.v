// IEEE 1800-2023 19.7 Table 19-2: cross_retain_auto_bins is an
// instance option on a covergroup (as the default for crosses) or on a cross.
// It is neither a coverpoint option nor a type_option.
module top;
  int value;

  covergroup bad_coverpoint_scope;
    cp: coverpoint value {
      option.cross_retain_auto_bins = 0;
    }
  endgroup

  covergroup bad_type_scope;
    type_option.cross_retain_auto_bins = 0;
    cp: coverpoint value;
  endgroup
endmodule

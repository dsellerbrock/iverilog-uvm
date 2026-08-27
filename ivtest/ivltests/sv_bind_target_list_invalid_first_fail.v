// IEEE 1800-2017/2023 23.11: every selected target-list entry is evaluated.
// A later valid duplicate must not hide the first entry's nonconstant select.
module sv_bind_target_list_invalid_first_probe;
endmodule

module sv_bind_target_list_invalid_first_leaf;
endmodule

module sv_bind_target_list_invalid_first_fail;
  integer IDX;
  sv_bind_target_list_invalid_first_leaf targets[0:0]();

  bind sv_bind_target_list_invalid_first_leaf : targets[IDX], targets[0]
    sv_bind_target_list_invalid_first_probe bp();
endmodule

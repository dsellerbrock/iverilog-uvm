// IEEE 1800-2017/2023 23.11: target-list validation is source-order
// independent. A valid first entry must not suppress a later nonconstant
// target select.
module sv_bind_target_list_invalid_last_probe;
endmodule

module sv_bind_target_list_invalid_last_leaf;
endmodule

module sv_bind_target_list_invalid_last_fail;
  integer IDX;
  sv_bind_target_list_invalid_last_leaf targets[0:0]();

  bind sv_bind_target_list_invalid_last_leaf : targets[0], targets[IDX]
    sv_bind_target_list_invalid_last_probe bp();
endmodule

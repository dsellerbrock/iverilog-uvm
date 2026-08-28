// IEEE 1800-2017/2023 23.11: a definition bind cannot propagate into an
// instance introduced by another bind. This source-order partner declares
// the inner definition bind first.
module sv_bind_nested_direct_first_probe;
endmodule

module sv_bind_nested_direct_first_leaf;
endmodule

module sv_bind_nested_direct_first_fail;
endmodule

bind sv_bind_nested_direct_first_leaf
  sv_bind_nested_direct_first_probe p();
bind sv_bind_nested_direct_first_fail
  sv_bind_nested_direct_first_leaf b();

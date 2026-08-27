// IEEE 1800-2017/2023 23.11: reverse-order partner for propagation of a
// definition bind into an instance introduced by another bind.
module sv_bind_nested_direct_reversed_probe;
endmodule

module sv_bind_nested_direct_reversed_leaf;
endmodule

module sv_bind_nested_direct_reversed_fail;
endmodule

bind sv_bind_nested_direct_reversed_fail
  sv_bind_nested_direct_reversed_leaf b();
bind sv_bind_nested_direct_reversed_leaf
  sv_bind_nested_direct_reversed_probe p();

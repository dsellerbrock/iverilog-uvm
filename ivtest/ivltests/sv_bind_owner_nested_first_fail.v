// IEEE 1800-2017/2023 23.11: it is illegal to bind underneath an instance
// introduced by another bind. The result is independent of directive order.
module sv_bind_owner_nested_first_leaf;
endmodule

module sv_bind_owner_nested_first_container;
  sv_bind_owner_nested_first_leaf nested();
endmodule

module sv_bind_owner_nested_first_probe;
endmodule

module sv_bind_owner_nested_first_fail;
endmodule

bind sv_bind_owner_nested_first_fail
  sv_bind_owner_nested_first_container b1();
bind sv_bind_owner_nested_first_fail.b1.nested
  sv_bind_owner_nested_first_probe b2();

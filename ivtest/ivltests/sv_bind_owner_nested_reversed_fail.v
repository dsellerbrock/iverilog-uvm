// IEEE 1800-2017/2023 23.11: reverse-order partner for the illegal
// bind-under-bind case. Resolution must not depend on source order.
module sv_bind_owner_nested_reversed_leaf;
endmodule

module sv_bind_owner_nested_reversed_container;
  sv_bind_owner_nested_reversed_leaf nested();
endmodule

module sv_bind_owner_nested_reversed_probe;
endmodule

module sv_bind_owner_nested_reversed_fail;
endmodule

bind sv_bind_owner_nested_reversed_fail.b1.nested
  sv_bind_owner_nested_reversed_probe b2();
bind sv_bind_owner_nested_reversed_fail
  sv_bind_owner_nested_reversed_container b1();

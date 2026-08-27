// IEEE 1800-2017/2023 23.11: a relative bind target select is evaluated
// separately in each parameter-specialized instance of the containing module.
// A valid occurrence must not suppress the out-of-range occurrence.
module sv_bind_owner_select_specialization_probe;
endmodule

module sv_bind_owner_select_specialization_leaf;
endmodule

module sv_bind_owner_select_specialization_holder #(
  parameter int SELECTED = 1
);
  sv_bind_owner_select_specialization_leaf children[1:0]();
  bind children[SELECTED]
    sv_bind_owner_select_specialization_probe bp();
endmodule

module sv_bind_owner_select_specialization_fail;
  sv_bind_owner_select_specialization_holder #(.SELECTED(1)) good();
  sv_bind_owner_select_specialization_holder #(.SELECTED(2)) bad();
endmodule

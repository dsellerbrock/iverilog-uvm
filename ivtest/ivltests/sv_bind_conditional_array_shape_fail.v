// IEEE 1800-2017/2023 23.11/27.5: same-named conditional alternatives are
// checked per owner occurrence. A scalar target binds successfully, while an
// active arrayed target without a final element select is a focused error.
module sv_bind_conditional_array_shape_probe;
endmodule

module sv_bind_conditional_array_shape_leaf;
endmodule

module sv_bind_conditional_array_shape_holder #(
  parameter bit ARRAYED = 1'b0
);
  if (ARRAYED) begin : selected
    sv_bind_conditional_array_shape_leaf child[0:1]();
  end else begin : selected
    sv_bind_conditional_array_shape_leaf child();
  end

  bind selected.child sv_bind_conditional_array_shape_probe p();
endmodule

module sv_bind_conditional_array_shape_fail;
  sv_bind_conditional_array_shape_holder #(.ARRAYED(1'b0)) scalar();
  sv_bind_conditional_array_shape_holder #(.ARRAYED(1'b1)) arrayed();
endmodule

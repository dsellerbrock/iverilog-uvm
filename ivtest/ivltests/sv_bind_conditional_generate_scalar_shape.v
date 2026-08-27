// IEEE 1800-2017/2023 23.11/27.5: the inverse active-specialization case.
// The selected scalar generate scope accepts an unselected path even though
// the inactive case alternative with the same label is a loop-generate array.
package sv_bind_conditional_generate_scalar_shape_counts;
  int hits;
endpackage

module sv_bind_conditional_generate_scalar_shape_leaf;
endmodule

module sv_bind_conditional_generate_scalar_shape_probe;
  initial sv_bind_conditional_generate_scalar_shape_counts::hits =
    sv_bind_conditional_generate_scalar_shape_counts::hits + 1;
endmodule

module sv_bind_conditional_generate_scalar_shape_holder #(
  parameter int MODE = 1
);
  case (MODE)
    0: for (genvar i = 0; i < 1; i++) begin : selected
      sv_bind_conditional_generate_scalar_shape_leaf child();
    end
    default: begin : selected
      sv_bind_conditional_generate_scalar_shape_leaf child();
    end
  endcase

  bind selected.child sv_bind_conditional_generate_scalar_shape_probe p();
endmodule

module sv_bind_conditional_generate_scalar_shape;
  sv_bind_conditional_generate_scalar_shape_holder #(.MODE(1)) owner();

  initial begin
    #1;
    if (sv_bind_conditional_generate_scalar_shape_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_conditional_generate_scalar_shape_counts::hits);
  end
endmodule

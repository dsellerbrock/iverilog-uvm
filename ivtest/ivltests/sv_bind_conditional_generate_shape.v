// IEEE 1800-2017/2023 23.11/27.5: path-shape validation is per active
// declaration-owner specialization. The inactive scalar case alternative
// sharing the label `selected` must not invalidate the selected loop-generate
// occurrence named by selected[0].child.
package sv_bind_conditional_generate_shape_counts;
  int hits;
endpackage

module sv_bind_conditional_generate_shape_leaf;
endmodule

module sv_bind_conditional_generate_shape_probe;
  initial sv_bind_conditional_generate_shape_counts::hits =
    sv_bind_conditional_generate_shape_counts::hits + 1;
endmodule

module sv_bind_conditional_generate_shape_holder #(
  parameter int MODE = 0
);
  case (MODE)
    0: for (genvar i = 0; i < 1; i++) begin : selected
      sv_bind_conditional_generate_shape_leaf child();
    end
    default: begin : selected
      sv_bind_conditional_generate_shape_leaf child();
    end
  endcase

  bind selected[0].child sv_bind_conditional_generate_shape_probe p();
endmodule

module sv_bind_conditional_generate_shape;
  sv_bind_conditional_generate_shape_holder #(.MODE(0)) owner();

  initial begin
    #1;
    if (sv_bind_conditional_generate_shape_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_conditional_generate_shape_counts::hits);
  end
endmodule

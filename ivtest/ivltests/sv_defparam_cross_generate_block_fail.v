// IEEE 1800-2017/2023 §23.10.1 forbids targeting another instance of the
// same generate block.
module sv_defparam_cross_generate_leaf #(parameter integer P = 0) ();
endmodule

module sv_defparam_cross_generate_block_fail;
  genvar i;
  generate
    for (i = 0; i < 2; i = i + 1) begin : genblk
      sv_defparam_cross_generate_leaf u();
      defparam genblk[1].u.P = i;
    end
  endgenerate
endmodule

// Same-instance defparams and module-scope overrides into a generated scope
// remain legal under IEEE 1800-2017/2023 §23.10.1.
module sv_defparam_same_generate_leaf #(parameter integer P = 0) ();
endmodule

module sv_defparam_same_generate_block;
  genvar i;
  generate
    for (i = 0; i < 2; i = i + 1) begin : genblk
      sv_defparam_same_generate_leaf local_u();
      sv_defparam_same_generate_leaf external_u();
      defparam local_u.P = i;
    end
  endgenerate
  defparam genblk[1].external_u.P = 7;

  initial begin
    if (genblk[0].local_u.P !== 0 || genblk[1].local_u.P !== 1 ||
        genblk[1].external_u.P !== 7)
      $fatal(1, "unexpected defparam result");
    $display("PASSED");
  end
endmodule

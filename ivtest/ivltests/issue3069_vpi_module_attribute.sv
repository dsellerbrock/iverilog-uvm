(* shared = int'(23), duplicate = 8'h01 *)
(* duplicate = 8'ha5 *)
module leaf #(parameter int TUNE = 100)(input wire p);
endmodule

module plain;
endmodule

(* flag, byteattr = 8'hf1 *)
module top #(parameter int TUNE = 1);
  wire p = 1'b0;

  (* shared = TUNE, signed_value = -9'sd13, wide = {1'b1, 64'b0, 2'bxz} *)
  (* fraction = 2.75, text = "A\"\\\nB" *)
  leaf #(.TUNE(21)) u(.p(p)), bank[1:0](.p(p));

  (* shared = TUNE *)
  leaf #(34) v(p), w(p);

  plain unannotated();
  defparam TUNE = 17;
  defparam u.TUNE = 23;
  initial $inspect_module_attributes;
endmodule

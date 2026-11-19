module leaf #(parameter int VALUE = 0);
  (* instance_value = VALUE *) logic state;
endmodule

module top;
  (* probe_attr = 3 *) logic x;
  logic plain;

  (* flag, signed_value = -9'sd13, wide = {1'b1, 64'b0, 2'bxz},
     fraction = 2.75, text = "A\"\\\nB", duplicate = -1 *)
  (* duplicate = 16 *) logic a, b;

  (* array_attr = 7 *) int fixed_array [0:1];
  (* queue_attr = 8 *) logic queue_var [$];
  (* real_owner = 9 *) real r;
  (* string_owner = 10 *) string s;
  (* time_value = time'(64'h0000_0001_0000_0003) *) logic timed;
  (* \quote"name = 12 *) logic escaped;

  leaf #(.VALUE(21)) u();
  leaf #(.VALUE(34)) v();

  initial $inspect_variable_attributes;
  ref_probe refs(x, r);
  (* one_bit_vector = 1'bz *) logic vector_value;
endmodule

module ref_probe(
  (* ref_attr = 13 *) ref logic x,
  (* ref_attr = 14 *) ref real r
);
endmodule

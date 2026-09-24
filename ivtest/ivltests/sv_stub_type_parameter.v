module child #(
  parameter type T = logic [3:0],
  parameter Width = $bits(T)
) (
  input T d,
  output T q
);
  assign q = d;
endmodule

module test;
  logic [3:0] d;
  logic [3:0] q_default, q_override;
  child default_type(.d(d), .q(q_default));
  child #(.T(logic [3:0]), .Width(4)) overridden_type(.d(d), .q(q_override));
endmodule

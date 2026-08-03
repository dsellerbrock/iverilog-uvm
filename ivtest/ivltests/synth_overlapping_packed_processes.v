`begin_keywords "1800-2012"

module main(
  input  logic [2:0] d,
  output logic [2:0] q
);
  always_comb q[1:0] = d[1:0];
  always_comb q[2:1] = d[2:1];
endmodule

`end_keywords

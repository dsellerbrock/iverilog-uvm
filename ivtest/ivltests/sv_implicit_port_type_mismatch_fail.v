module sv_implicit_port_type_mismatch_child (
    input logic [7:0] d = 8'h5A,
    output logic [7:0] q
);
  assign q = d;
endmodule

module sv_implicit_port_wildcard_type_child (
    input logic [7:0] d_wild = 8'hC3,
    output logic [7:0] q
);
  assign q = d_wild;
endmodule

module sv_implicit_port_type_mismatch_fail;
  logic [3:0] d;
  logic signed [7:0] d_wild;
  logic [3:0] q;

  sv_implicit_port_type_mismatch_child by_name(.d, .q());
  sv_implicit_port_wildcard_type_child by_wildcard(.*);
endmodule

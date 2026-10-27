module sv_implicit_port_type_child (
    input logic [7:0] d = 8'h5A,
    output logic [7:0] q
);
  assign q = d;
endmodule

module sv_implicit_port_default_child (
    input logic [7:0] source = 8'hC3,
    output logic [7:0] result
);
  assign result = source;
endmodule

module sv_implicit_port_type_controls;
  logic [7:0] d;
  logic [3:0] narrow;
  logic [7:0] q_name, q_wildcard, q_explicit, result;

  sv_implicit_port_type_child by_name(.d, .q(q_name));
  sv_implicit_port_type_child by_wildcard(.*, .q(q_wildcard));
  sv_implicit_port_type_child by_explicit(.d(narrow), .q(q_explicit));
  sv_implicit_port_default_child default_wildcard(.*);

  initial begin
    d = 8'h36;
    narrow = 4'hA;
    #1;
    if (q_name !== 8'h36 || q_wildcard !== 8'h36
        || q_explicit !== 8'h0A || result !== 8'hC3)
      $fatal(1, "implicit port type controls mismatch");
    $display("PASSED");
  end
endmodule

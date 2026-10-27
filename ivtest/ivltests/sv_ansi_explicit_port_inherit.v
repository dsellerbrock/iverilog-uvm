module sv_ansi_explicit_port_inherit_inner (
    input wire integer p_a, .p_b(s_b), p_c
);
  logic [5:0] s_b;

  initial begin
    #1;
    if ($bits(p_a) != 32 || $bits(s_b) != 6 || $bits(p_c) != 1)
      $fatal(1, "port widths");
    if (p_a !== 32'h12345678 || s_b !== 6'h2d || p_c !== 1'b1)
      $fatal(1, "port directions or connections");
    $display("PASS");
    $finish;
  end
endmodule

module sv_ansi_explicit_port_inherit;
  logic [31:0] a;
  logic [5:0] b;
  logic c;

  sv_ansi_explicit_port_inherit_inner dut (
      .p_a(a), .p_b(b), .p_c(c)
  );

  initial begin
    a = 32'h12345678;
    b = 6'h2d;
    c = 1'b1;
  end
endmodule

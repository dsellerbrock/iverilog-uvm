module basic_net_decl;
  wire c, a = 1, b = 0;
  initial $display("BASIC %b %b %b", a, b, c);
endmodule

module parameterized_net_decl #(parameter int P = 1) ();
  wire a = P, b = 0, c;
  initial $display("PARAM %b %b %b", a, b, c);
endmodule

module sv_net_decl_mixed_init;
  basic_net_decl basic();
  parameterized_net_decl parameterized();
endmodule

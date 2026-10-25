module sv_scope_randomize_expr_fail;
  int a;
  initial void'(std::randomize(a + 1));
endmodule

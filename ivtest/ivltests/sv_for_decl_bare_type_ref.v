// IEEE 1800-2017/2023 Syntax 12-5 footnote 14: a for_variable_declaration
// data_type may be a type_reference only in the `var type(expr)' form. The
// bare spelling is not a legal declaration here.
module sv_for_decl_bare_type_ref;
  int seed;
  initial for (type(seed) g = 0; g < 1; g++) ;
endmodule
